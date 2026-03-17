require 'rails_helper'

RSpec.describe "Quizzes", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/quizzes/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/quizzes/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/quizzes/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/quizzes/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/quizzes/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/quizzes/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/quizzes/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /generate" do
    it "returns http success" do
      get "/quizzes/generate"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /take" do
    it "returns http success" do
      get "/quizzes/take"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /submit" do
    it "returns http success" do
      get "/quizzes/submit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /results" do
    it "returns http success" do
      get "/quizzes/results"
      expect(response).to have_http_status(:success)
    end
  end

end
