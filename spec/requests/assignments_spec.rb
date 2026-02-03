require 'rails_helper'

RSpec.describe "Assignments", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/assignments/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/assignments/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/assignments/create"
      expect(response).to have_http_status(:success)
    end
  end

end
