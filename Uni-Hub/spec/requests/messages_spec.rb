require 'rails_helper'

RSpec.describe "Messages", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/messages/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/messages/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/messages/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/messages/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /conversations" do
    it "returns http success" do
      get "/messages/conversations"
      expect(response).to have_http_status(:success)
    end
  end

end
