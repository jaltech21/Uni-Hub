require 'test_helper'

class ActivityFeedIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @department = departments(:computer_science)
    @admin.update(department: @department)
    
    # Create test activities
    create_test_activities
  end

  test "complete activity feed workflow" do
    sign_in_as(@admin)
    
    # Visit activity feed
    get department_activity_index_path(@department)
    assert_response :success
    assert_select 'h1', /Activity Feed/
    assert_select '#activityFeed'
    assert_select '#filtersPanel'
    
    # Check activity type filters are present
    assert_select 'input[name="activity_types[]"]', count: 6
    assert_select '.activity-type-filter'
    
    # Check date filters are present
    assert_select '#dateFrom'
    assert_select '#dateTo'
    assert_select '.date-preset-btn'
    
    # Check user filter is present
    assert_select '#userFilter'
    
    # Test AJAX filter request
    get filter_department_activity_index_path(@department),
        params: { activity_types: ['content_sharing'] },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('activities')
    assert json_response.key?('has_more')
    assert json_response.key?('total_count')
    
    # Test load more functionality
    get load_more_department_activity_index_path(@department),
        params: { page: 2 },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?('activities')
  end

  test "activity filtering and JSON response structure" do
    sign_in_as(@admin)
    
    # Test filtering by activity type
    get filter_department_activity_index_path(@department),
        params: { activity_types: ['content_sharing', 'member_changes'] },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # Verify JSON structure
    assert json_response.key?('activities')
    assert json_response.key?('has_more')
    assert json_response.key?('total_count')
    
    activities = json_response['activities']
    if activities.any?
      activity = activities.first
      
      # Check required fields in activity object
      required_fields = %w[id type title description user_name formatted_time formatted_date icon color url]
      required_fields.each do |field|
        assert activity.key?(field), "Activity missing field: #{field}"
      end
      
      # Verify activity types match filter
      activities.each do |act|
        assert_includes ['content_sharing', 'member_change'], act['type'],
                       "Activity type #{act['type']} not in filter"
      end
    end
  end

  test "date range filtering" do
    sign_in_as(@admin)
    
    # Test with specific date range
    from_date = 1.week.ago.to_date
    to_date = Date.today
    
    get filter_department_activity_index_path(@department),
        params: { 
          date_from: from_date.to_s,
          date_to: to_date.to_s
        },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    activities = json_response['activities']
    activities.each do |activity|
      activity_date = Date.parse(activity['formatted_date'])
      assert activity_date >= from_date, "Activity date #{activity_date} before filter start"
      assert activity_date <= to_date, "Activity date #{activity_date} after filter end"
    end
  end

  test "user-specific filtering" do
    sign_in_as(@admin)
    
    user = @department.users.first
    return unless user # Skip if no users in department
    
    get filter_department_activity_index_path(@department),
        params: { user_id: user.id },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    # All activities should be from the specified user
    activities = json_response['activities']
    activities.each do |activity|
      assert_match /#{user.first_name}/, activity['user_name'],
                   "Activity not from specified user: #{activity['user_name']}"
    end
  end

  test "pagination and load more functionality" do
    sign_in_as(@admin)
    
    # Get first page
    get filter_department_activity_index_path(@department),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    page_1 = JSON.parse(response.body)
    
    # Get second page
    get load_more_department_activity_index_path(@department),
        params: { page: 2 },
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    page_2 = JSON.parse(response.body)
    
    # Verify no overlapping activities between pages
    page_1_ids = page_1['activities'].map { |a| a['id'] }
    page_2_ids = page_2['activities'].map { |a| a['id'] }
    
    overlapping = page_1_ids & page_2_ids
    assert_empty overlapping, "Pages should not have overlapping activities"
  end

  test "unauthorized access prevention" do
    # Try without authentication
    get department_activity_index_path(@department)
    assert_redirected_to new_user_session_path
    
    # Try with user from different department
    other_user = users(:student)
    other_department = departments(:physics)
    other_user.update(department: other_department)
    
    sign_in_as(other_user)
    get department_activity_index_path(@department)
    assert_redirected_to departments_path
    assert_match /access/, flash[:alert]
  end

  test "empty activity feed handling" do 
    sign_in_as(@admin)
    
    # Create department with no activities
    empty_dept = Department.create!(
      name: 'Empty Test Department',
      code: 'EMPTY',
      university: universities(:test_university)
    )
    empty_dept.users << @admin
    
    get department_activity_index_path(empty_dept)
    assert_response :success
    
    # Test AJAX request returns empty activities
    get filter_department_activity_index_path(empty_dept),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_empty json_response['activities']
    assert_equal false, json_response['has_more']
    assert_equal 0, json_response['total_count']
  end

  test "activity feed statistics and overview" do
    sign_in_as(@admin)
    
    get department_activity_index_path(@department)
    assert_response :success
    
    # Should display activity type statistics
    assert_select '.activity-type-filter', count: 6
    
    # Each activity type should show count
    activity_types = ['announcements', 'content_sharing', 'member_changes', 'assignments', 'quizzes', 'notes']
    activity_types.each do |type|
      assert_select "input[value='#{type}']"
    end
  end

  test "real-time updates simulation" do
    sign_in_as(@admin)
    
    # Get initial activity count
    get filter_department_activity_index_path(@department),
        headers: { 'Accept' => 'application/json' }
    
    initial_response = JSON.parse(response.body)
    initial_count = initial_response['total_count']
    
    # Create new activity (simulate real-time update)
    new_user = User.create!(
      email: 'newuser@example.com',
      password: 'password123',
      first_name: 'New',
      last_name: 'User',
      role: 'student',
      department: @department
    )
    
    DepartmentMemberHistory.create!(
      user: new_user,
      department: @department,
      action: 'joined'
    )
    
    # Get updated activity count
    get filter_department_activity_index_path(@department),
        headers: { 'Accept' => 'application/json' }
    
    updated_response = JSON.parse(response.body)
    updated_count = updated_response['total_count']
    
    # Should have more activities now
    assert updated_count > initial_count, "Activity count should increase after new activity"
  end

  private

  def create_test_activities
    # Create test users
    user1 = User.create!(
      email: 'testuser1@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User1',
      role: 'student',
      department: @department
    )
    
    user2 = User.create!(
      email: 'testuser2@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User2',
      role: 'teacher',
      department: @department
    )
    
    # Create content sharing activity
    ContentSharingHistory.create!(
      shareable_type: 'Assignment',
      shareable_id: 1,
      department: @department,
      shared_by: user1,
      action: 'shared',
      created_at: 2.days.ago
    )
    
    # Create member change activity
    DepartmentMemberHistory.create!(
      user: user2,
      department: @department,
      action: 'joined',
      created_at: 1.day.ago
    )
    
    # Create assignment activity (if Assignment model exists)
    begin
      Assignment.create!(
        title: 'Test Assignment',
        description: 'Test description',
        user: user2,
        due_date: 1.week.from_now,
        created_at: 3.hours.ago
      )
    rescue NameError
      # Assignment model might not exist, skip
    end
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end