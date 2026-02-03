require 'rails_helper'

RSpec.describe "Folders", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/folders/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/folders/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/folders/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/folders/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
