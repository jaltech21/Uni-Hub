require 'rails_helper'

RSpec.describe "Searches", type: :request do
  let(:user) { User.create!(email: 'test@example.com', password: 'password123', role: 'student', first_name: 'Test', last_name: 'User') }
  
  before do
    sign_in user
  end

  describe "GET /search" do
    it "returns http success" do
      get "/search"
      expect(response).to have_http_status(:success)
    end
    
    it "renders the search index template" do
      get "/search"
      expect(response).to render_template(:index)
    end
    
    it "assigns search filters" do
      get "/search"
      expect(assigns(:search_filters)).to be_present
      expect(assigns(:popular_searches)).to be_present
    end
  end

  describe "GET /search/results" do
    context "with a search query" do
      it "returns http success" do
        get "/search/results", params: { q: "test" }
        expect(response).to have_http_status(:success)
      end
      
      it "renders the results template" do
        get "/search/results", params: { q: "test" }
        expect(response).to render_template(:results)
      end
      
      it "assigns search results" do
        get "/search/results", params: { q: "test" }
        expect(assigns(:search_results)).to be_present
        expect(assigns(:query)).to eq("test")
      end
    end
    
    context "without a search query" do
      it "returns http success" do
        get "/search/results"
        expect(response).to have_http_status(:success)
      end
      
      it "returns empty results" do
        get "/search/results"
        expect(assigns(:search_results)[:total_results]).to eq(0)
      end
    end
    
    context "with filters" do
      it "applies filters correctly" do
        get "/search/results", params: { q: "test", type: "notes" }
        expect(assigns(:filters)[:type]).to eq("notes")
      end
    end
  end

  describe "GET /search/suggestions" do
    context "with JSON format" do
      it "returns http success" do
        get "/search/suggestions", params: { q: "te" }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:success)
      end
      
      it "returns JSON response" do
        get "/search/suggestions", params: { q: "te" }, headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to eq("application/json; charset=utf-8")
      end
      
      it "returns suggestions structure" do
        get "/search/suggestions", params: { q: "te" }, headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key("suggestions")
        expect(json_response).to have_key("query_suggestions")
        expect(json_response).to have_key("query")
      end
    end
    
    context "with short query" do
      it "returns empty suggestions for short queries" do
        get "/search/suggestions", params: { q: "t" }, headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response["suggestions"]).to be_empty
        expect(json_response["query_suggestions"]).to be_empty
      end
    end
  end
  
  describe "search functionality with data" do
    let!(:note) { Note.create!(title: "Machine Learning Notes", content: "Deep learning algorithms", user: user) }
    let!(:assignment) { Assignment.create!(title: "ML Assignment", description: "Machine learning homework", user: user, due_date: 1.week.from_now, points: 100) }
    
    it "finds relevant notes" do
      get "/search/results", params: { q: "machine learning" }
      expect(assigns(:search_results)[:results]['notes']).to be_present
      expect(assigns(:search_results)[:total_results]).to be > 0
    end
    
    it "finds relevant assignments" do
      get "/search/results", params: { q: "ML" }
      expect(assigns(:search_results)[:results]['assignments']).to be_present
    end
    
    it "filters by content type" do
      get "/search/results", params: { q: "machine", type: "notes" }
      expect(assigns(:search_results)[:results]).to have_key('notes')
      expect(assigns(:search_results)[:results]).not_to have_key('assignments')
    end
  end
end
