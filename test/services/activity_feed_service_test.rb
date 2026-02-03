require 'test_helper'

class ActivityFeedServiceTest < ActiveSupport::TestCase
  setup do
    @department = departments(:computer_science)
    @service = ActivityFeedService.new(@department)
  end

  test "should initialize with department" do
    assert_equal @department, @service.department
  end

  test "should return activity types summary" do
    summary = @service.activity_types_summary
    
    assert summary.is_a?(Array)
    assert_equal 6, summary.length
    
    # Check structure of first activity type
    first_type = summary.first
    required_keys = [:key, :label, :icon, :count, :color]
    required_keys.each do |key|
      assert first_type.key?(key), "Missing key: #{key}"
    end
    
    # Verify specific activity types are present
    activity_keys = summary.map { |type| type[:key] }
    expected_keys = ['announcements', 'content_sharing', 'member_changes', 'assignments', 'quizzes', 'notes']
    expected_keys.each do |key|
      assert_includes activity_keys, key, "Missing activity type: #{key}"
    end
  end

  test "should load activities with pagination" do
    activities = @service.load_activities(page: 1)
    
    assert activities.is_a?(Array)
    assert activities.length <= 20 # Per page limit
  end

  test "should return recent activity stats" do
    stats = @service.recent_activity_stats(7)
    
    assert stats.is_a?(Hash)
    expected_keys = [:announcements, :content_shares, :member_changes, :assignments, :quizzes, :notes]
    expected_keys.each do |key|
      assert stats.key?(key), "Missing stat key: #{key}"
      assert stats[key].is_a?(Integer), "Stat #{key} should be integer"
    end
  end

  test "should return most active users" do
    active_users = @service.most_active_users(5)
    
    assert active_users.is_a?(Array)
    assert active_users.length <= 5
    
    if active_users.any?
      user_info = active_users.first
      required_keys = [:user, :activity_count, :name, :role]
      required_keys.each do |key|
        assert user_info.key?(key), "Missing user info key: #{key}"
      end
    end
  end

  test "should filter activities by type" do
    filtered_service = ActivityFeedService.new(@department, {
      activity_types: ['content_sharing', 'assignments']
    })
    
    activities = filtered_service.load_activities
    
    # All activities should be of specified types
    activities.each do |activity|
      assert_includes ['content_sharing', 'assignment'], activity[:type]
    end
  end

  test "should filter activities by date range" do
    filtered_service = ActivityFeedService.new(@department, {
      date_from: 1.week.ago.to_date.to_s,
      date_to: Date.today.to_s
    })
    
    activities = filtered_service.load_activities
    
    # All activities should be within date range
    activities.each do |activity|
      assert activity[:timestamp] >= 1.week.ago
      assert activity[:timestamp] <= Date.today.end_of_day
    end
  end

  test "should filter activities by user" do
    user = @department.users.first
    return unless user # Skip if no users
    
    filtered_service = ActivityFeedService.new(@department, {
      user_id: user.id
    })
    
    activities = filtered_service.load_activities
    
    # All activities should be from specified user
    activities.each do |activity|
      assert_equal user.id, activity[:user].id
    end
  end

  test "should handle empty filters gracefully" do
    empty_service = ActivityFeedService.new(@department, {})
    activities = empty_service.load_activities
    
    assert activities.is_a?(Array)
  end

  test "should return properly structured activity objects" do
    activities = @service.load_activities
    
    if activities.any?
      activity = activities.first
      required_fields = [:id, :type, :title, :description, :user, :timestamp, :icon, :color, :url, :metadata]
      
      required_fields.each do |field|
        assert activity.key?(field), "Activity missing field: #{field}"
      end
      
      # Verify data types
      assert activity[:id].is_a?(String)
      assert activity[:type].is_a?(String)
      assert activity[:title].is_a?(String)
      assert activity[:user].respond_to?(:first_name)
      assert activity[:timestamp].is_a?(Time) || activity[:timestamp].is_a?(ActiveSupport::TimeWithZone)
      assert activity[:metadata].is_a?(Hash)
    end
  end

  test "should sort activities by timestamp descending" do
    activities = @service.load_activities
    
    if activities.length > 1
      # Verify activities are sorted by timestamp (newest first)
      activities.each_cons(2) do |current, next_activity|
        assert current[:timestamp] >= next_activity[:timestamp], 
               "Activities not properly sorted by timestamp"
      end
    end
  end

  test "should handle pagination correctly" do
    # Test first page
    page_1 = @service.load_activities(page: 1)
    page_2 = @service.load_activities(page: 2)
    
    # Pages should not have overlapping activities (if we have enough data)
    page_1_ids = page_1.map { |a| a[:id] }
    page_2_ids = page_2.map { |a| a[:id] }
    
    overlapping_ids = page_1_ids & page_2_ids
    assert_empty overlapping_ids, "Pages should not have overlapping activities"
  end

  test "should truncate long descriptions" do
    # This test assumes we have some activities with descriptions
    activities = @service.load_activities
    
    activities.each do |activity|
      if activity[:description].present?
        assert activity[:description].length <= 153, # 150 + "..."
               "Description should be truncated: #{activity[:description].length} chars"
      end
    end
  end
end