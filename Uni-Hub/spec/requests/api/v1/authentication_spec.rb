require "rails_helper"

RSpec.describe "Api::V1::Authentication", type: :request do
  let(:password) { "Password1!" }
  let!(:user) do
    User.create!(
      email: "student@example.com",
      password: password,
      password_confirmation: password,
      first_name: "John",
      last_name: "Doe",
      username: "johndoe",
      role: "student"
    )
  end

  def json_body
    JSON.parse(response.body)
  end

  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/auth/login" do
    it "issues access + refresh tokens for valid credentials" do
      post "/api/v1/auth/login", params: { email: user.email, password: password }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body["success"]).to be true
      expect(json_body.dig("data", "token")).to be_present
      expect(json_body.dig("data", "refresh_token")).to be_present
      expect(json_body.dig("data", "user", "email")).to eq(user.email)
      expect(json_body.dig("data", "user", "role")).to eq("student")
      expect(RefreshToken.where(user: user).count).to eq(1)
    end

    it "is case-insensitive on email" do
      post "/api/v1/auth/login", params: { email: user.email.upcase, password: password }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "returns 401 with AUTH_FAILED for a wrong password" do
      post "/api/v1/auth/login", params: { email: user.email, password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("AUTH_FAILED")
    end

    it "returns 401 with AUTH_FAILED for an unknown email" do
      post "/api/v1/auth/login", params: { email: "nobody@example.com", password: password }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("AUTH_FAILED")
    end

    it "rejects blacklisted users" do
      user.update!(blacklisted: true)
      post "/api/v1/auth/login", params: { email: user.email, password: password }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("ACCOUNT_INACTIVE")
    end
  end

  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      {
        first_name: "Jane",
        last_name: "Smith",
        email: "jane@example.com",
        username: "janesmith",
        password: "Password1!",
        password_confirmation: "Password1!",
        role: "student"
      }
    end

    it "creates a user and returns tokens" do
      expect {
        post "/api/v1/auth/register", params: valid_params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body.dig("data", "user", "email")).to eq("jane@example.com")
      expect(json_body.dig("data", "token")).to be_present
      expect(json_body.dig("data", "refresh_token")).to be_present
    end

    it "returns 422 with field-level errors for duplicate email" do
      post "/api/v1/auth/register", params: valid_params.merge(email: user.email), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "code")).to eq("VALIDATION_ERROR")
      expect(json_body.dig("error", "errors", "email")).to include("has already been taken")
    end
  end

  describe "GET /api/v1/auth/current_user" do
    it "returns the authenticated user's profile" do
      token = JsonWebToken.encode({ sub: user.id, type: "access" })
      get "/api/v1/auth/current_user", headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "id")).to eq(user.id)
      expect(json_body.dig("data", "email")).to eq(user.email)
      expect(json_body.dig("data")).to have_key("department_name")
    end

    it "returns 401 without a token" do
      get "/api/v1/auth/current_user"
      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("TOKEN_INVALID")
    end

    it "returns 401 with TOKEN_EXPIRED for an expired token" do
      token = JsonWebToken.encode({ sub: user.id, type: "access" }, expires_at: 1.minute.ago)
      get "/api/v1/auth/current_user", headers: auth_headers(token)

      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("TOKEN_EXPIRED")
    end

    it "rejects a refresh token used as an access token" do
      token = JsonWebToken.encode({ sub: user.id, type: "refresh" })
      get "/api/v1/auth/current_user", headers: auth_headers(token)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/auth/refresh" do
    it "issues a new access token and rotates the refresh token" do
      _record, raw = RefreshToken.issue!(user)

      expect {
        post "/api/v1/auth/refresh", headers: auth_headers(raw)
      }.to change { RefreshToken.where(user: user).count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "token")).to be_present
      expect(json_body.dig("data", "refresh_token")).to be_present
      expect(json_body.dig("data", "refresh_token")).not_to eq(raw)
      expect(RefreshToken.active.where(user: user).count).to eq(1)
    end

    it "returns 401 for a missing refresh token" do
      post "/api/v1/auth/refresh"
      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("REFRESH_FAILED")
    end

    it "returns 401 for a revoked refresh token" do
      record, raw = RefreshToken.issue!(user)
      record.revoke!

      post "/api/v1/auth/refresh", headers: auth_headers(raw)
      expect(response).to have_http_status(:unauthorized)
      expect(json_body.dig("error", "code")).to eq("REFRESH_FAILED")
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "revokes the supplied refresh token" do
      access = JsonWebToken.encode({ sub: user.id, type: "access" })
      record, raw = RefreshToken.issue!(user)

      delete "/api/v1/auth/logout", params: { refresh_token: raw }, headers: auth_headers(access), as: :json

      expect(response).to have_http_status(:ok)
      expect(record.reload).to be_revoked
    end

    it "succeeds without a refresh token (client-only sign out)" do
      access = JsonWebToken.encode({ sub: user.id, type: "access" })
      delete "/api/v1/auth/logout", headers: auth_headers(access)
      expect(response).to have_http_status(:ok)
    end
  end
end
