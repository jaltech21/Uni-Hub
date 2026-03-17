require 'test_helper'

class Departments::ActivityControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @department = departments(:computer_science)
    @user.update(department: @department)
    sign_in @user
  end

  test "should get activity feed index" do
    get department_activity_index_path(@department)
    assert_response :success
    assert_select 'h1', /Activity Feed/
    assert_select '#activityFeed'
    assert_select '#filtersPanel'
  end

  test "should filter activities via AJAX" do
    get filter_department_activity_index_path(@department), 
        params: { activity_types: ['announcements', 'content_sharing'] },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('activities')
    assert json_response.key?('has_more')
  end

  test "should load more activities via AJAX" do
    get load_more_department_activity_index_path(@department),
        params: { page: 2 },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('activities')
    assert json_response['activities'].is_a?(Array)
  end

  test "should filter by date range" do
    get filter_department_activity_index_path(@department),
        params: { 
          date_from: 1.week.ago.to_date.to_s,
          date_to: Date.today.to_s
        },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('activities')
  end

  test "should filter by user" do
    user = @department.users.first
    get filter_department_activity_index_path(@department),
        params: { user_id: user.id },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('activities')
  end

  test "should require authentication" do
    sign_out @user
    get department_activity_index_path(@department)
    assert_redirected_to new_user_session_path
  end

  test "should require department membership" do
    other_department = departments(:physics)
    get department_activity_index_path(other_department)
    assert_redirected_to departments_path
    assert_match /access/, flash[:alert]
  end

  test "should handle empty activity feed" do
    # Create a department with no activities
    empty_dept = Department.create!(
      name: 'Empty Department',
      code: 'EMPTY',
      university: universities(:test_university)
    )
    empty_dept.users << @user

    get department_activity_index_path(empty_dept)
    assert_response :success
    assert_select '#emptyState', count: 0 # Hidden by default, shown by JS
  end

  test "should return proper JSON structure" do
    get filter_department_activity_index_path(@department),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # Verify JSON structure
    assert json_response.key?('activities')
    assert json_response.key?('has_more')
    assert json_response.key?('total_count')
    
    if json_response['activities'].any?
      activity = json_response['activities'].first
      required_fields = %w[id type title description user_name formatted_time icon color]
      required_fields.each do |field|
        assert activity.key?(field), "Activity missing field: #{field}"
      end
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end

  def sign_out(user)
    delete destroy_user_session_path
  end
end