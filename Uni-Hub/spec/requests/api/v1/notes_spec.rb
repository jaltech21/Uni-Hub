require "rails_helper"

RSpec.describe "Api::V1::Notes", type: :request do
  let(:password) { "Password1!" }

  # NotePolicy::Scope falls back to `where(department_id: user.department_id)` for
  # students — which becomes a wildcard when nil. Give each student their own
  # department so test users don't accidentally see each other's department-less notes.
  let!(:dept_a) { Department.create!(name: "CS-A", code: "CSA") }
  let!(:dept_b) { Department.create!(name: "CS-B", code: "CSB") }

  let!(:owner) do
    User.create!(
      email: "owner@example.com", password: password, password_confirmation: password,
      first_name: "Owner", last_name: "User", username: "owneruser", role: "student",
      department: dept_a
    )
  end

  let!(:other_user) do
    User.create!(
      email: "other@example.com", password: password, password_confirmation: password,
      first_name: "Other", last_name: "User", username: "otheruser", role: "student",
      department: dept_b
    )
  end

  let(:access_token) { JsonWebToken.encode({ sub: owner.id, type: "access" }) }
  let(:other_token)  { JsonWebToken.encode({ sub: other_user.id, type: "access" }) }
  let(:auth_headers) { { "Authorization" => "Bearer #{access_token}" } }

  def json_body
    JSON.parse(response.body)
  end

  describe "GET /api/v1/notes" do
    let!(:owned_note) { Note.create!(user: owner, title: "Mine", content: "owned content here") }
    let!(:other_note) { Note.create!(user: other_user, title: "Theirs", content: "not for you") }

    it "returns only the caller's notes" do
      get "/api/v1/notes", headers: auth_headers
      expect(response).to have_http_status(:ok)
      ids = json_body["data"].map { |n| n["id"] }
      expect(ids).to contain_exactly(owned_note.id)
    end

    it "includes pagination meta" do
      get "/api/v1/notes", headers: auth_headers
      expect(json_body["meta"]).to include("page" => 1, "total" => 1, "total_pages" => 1)
    end

    it "filters by search term" do
      Note.create!(user: owner, title: "React Basics", content: "lorem ipsum")
      get "/api/v1/notes", params: { search: "React" }, headers: auth_headers
      titles = json_body["data"].map { |n| n["title"] }
      expect(titles).to include("React Basics")
      expect(titles).not_to include("Mine")
    end

    it "filters by folder_id" do
      folder = Folder.create!(user: owner, name: "Web Dev")
      foldered = Note.create!(user: owner, title: "In folder", content: "x", folder: folder)
      get "/api/v1/notes", params: { folder_id: folder.id }, headers: auth_headers
      ids = json_body["data"].map { |n| n["id"] }
      expect(ids).to contain_exactly(foldered.id)
    end

    it "rejects unauthenticated requests" do
      get "/api/v1/notes"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/notes/:id" do
    let!(:note) { Note.create!(user: owner, title: "Mine", content: "secret stuff") }

    it "returns the note with shared_with present" do
      get "/api/v1/notes/#{note.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body.dig("data", "id")).to eq(note.id)
      expect(json_body["data"]).to have_key("shared_with")
    end

    it "returns 403 when a different user tries to view it" do
      get "/api/v1/notes/#{note.id}", headers: { "Authorization" => "Bearer #{other_token}" }
      expect(response).to have_http_status(:forbidden)
      expect(json_body.dig("error", "code")).to eq("FORBIDDEN")
    end

    it "returns 404 for an unknown id" do
      get "/api/v1/notes/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
      expect(json_body.dig("error", "code")).to eq("NOT_FOUND")
    end
  end

  describe "POST /api/v1/notes" do
    it "creates a note for the current user and attaches tags" do
      expect {
        post "/api/v1/notes",
          params: { title: "New Note", content: "body", tags: ["react", "hooks"] },
          headers: auth_headers, as: :json
      }.to change { owner.notes.count }.by(1)

      expect(response).to have_http_status(:created)
      tag_names = json_body.dig("data", "tags").map { |t| t["name"] }
      expect(tag_names).to contain_exactly("react", "hooks")
    end

    it "accepts tags as a comma-separated string" do
      post "/api/v1/notes",
        params: { title: "T", content: "body", tags: "a, b, c" },
        headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_body.dig("data", "tags").map { |t| t["name"] }).to contain_exactly("a", "b", "c")
    end

    it "returns 422 with field errors when title is missing" do
      post "/api/v1/notes", params: { content: "x" }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body.dig("error", "errors")).to include("title")
    end

    it "rejects unauthenticated requests" do
      post "/api/v1/notes", params: { title: "x", content: "y" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/notes/:id" do
    let!(:note) { Note.create!(user: owner, title: "Old", content: "old body") }

    it "updates the note" do
      patch "/api/v1/notes/#{note.id}",
        params: { title: "New" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(note.reload.title).to eq("New")
    end

    it "replaces tags when tags param is given" do
      note.tag_list = ["old"]
      note.save!

      patch "/api/v1/notes/#{note.id}",
        params: { tags: ["new"] }, headers: auth_headers, as: :json

      expect(json_body.dig("data", "tags").map { |t| t["name"] }).to contain_exactly("new")
    end

    it "returns 403 when a non-owner tries to update" do
      patch "/api/v1/notes/#{note.id}",
        params: { title: "Hacked" },
        headers: { "Authorization" => "Bearer #{other_token}" }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(note.reload.title).to eq("Old")
    end
  end

  describe "DELETE /api/v1/notes/:id" do
    let!(:note) { Note.create!(user: owner, title: "T", content: "x") }

    it "deletes the note" do
      expect {
        delete "/api/v1/notes/#{note.id}", headers: auth_headers
      }.to change(Note, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 when a non-owner tries to delete" do
      delete "/api/v1/notes/#{note.id}", headers: { "Authorization" => "Bearer #{other_token}" }
      expect(response).to have_http_status(:forbidden)
      expect(Note.exists?(note.id)).to be(true)
    end
  end
end
