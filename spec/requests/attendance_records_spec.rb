require 'rails_helper'

RSpec.describe "AttendanceRecords", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/attendance_records/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/attendance_records/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/attendance_records/create"
      expect(response).to have_http_status(:success)
    end
  end

end
