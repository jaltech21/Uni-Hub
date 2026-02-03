require 'test_helper'

class ActivityFeedViewTest < ActionView::TestCase
  include ApplicationHelper
  
  setup do
    @department = departments(:computer_science)
    @admin = users(:admin)
    @admin.update(department: @department)
    
    # Mock activity data
    @activities = [
      {
        'id' => 1,
        'type' => 'content_sharing',
        'title' => 'Assignment shared',
        'description' => 'Test assignment shared with department',
        'user_name' => 'John Doe',
        'formatted_time' => '2 hours ago',
        'formatted_date' => Date.today.strftime('%B %d, %Y'),
        'icon' => 'fas fa-share-alt',
        'color' => 'text-blue-600',
        'url' => '/assignments/1'
      },
      {
        'id' => 2,
        'type' => 'member_change',
        'title' => 'New member joined',
        'description' => 'Jane Smith joined the department',
        'user_name' => 'Jane Smith',
        'formatted_time' => '4 hours ago',
        'formatted_date' => Date.today.strftime('%B %d, %Y'),
        'icon' => 'fas fa-user-plus',
        'color' => 'text-green-600',
        'url' => '/users/2'
      }
    ]
    
    @activity_types_summary = {
      'announcements' => 5,
      'content_sharing' => 8,
      'member_changes' => 3,
      'assignments' => 12,
      'quizzes' => 4,
      'notes' => 7
    }
    
    @most_active_users = [
      { 'name' => 'John Doe', 'count' => 15 },
      { 'name' => 'Jane Smith', 'count' => 12 },
      { 'name' => 'Bob Johnson', 'count' => 8 }
    ]
  end

  test "should render activity feed index page" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: true,
             total_count: 25
           }
    
    # Check main structure
    assert_select 'h1', text: /Activity Feed/
    assert_select '#activityFeed'
    assert_select '#filtersPanel'
    assert_select '#loadMoreBtn'
    
    # Check activity items are rendered
    assert_select '.activity-item', count: 2
    
    # Check filters are present
    assert_select 'input[name="activity_types[]"]', count: 6
    assert_select '#dateFrom'
    assert_select '#dateTo'
    assert_select '#userFilter'
  end

  test "should render activity type filters correctly" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check each activity type filter
    @activity_types_summary.each do |type, count|
      assert_select "input[value='#{type}']"
      assert_select "label[for*='#{type}']", text: /#{count}/
    end
    
    # Check filter labels contain proper text
    assert_select 'label', text: /Announcements \(5\)/
    assert_select 'label', text: /Content Sharing \(8\)/
    assert_select 'label', text: /Member Changes \(3\)/
  end

  test "should render activity items with correct structure" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: true,
             total_count: 10
           }
    
    # Check first activity item
    assert_select '.activity-item:first-child' do
      assert_select '.activity-icon i.fas.fa-share-alt'
      assert_select '.activity-content h4', text: 'Assignment shared'
      assert_select '.activity-content p', text: 'Test assignment shared with department'
      assert_select '.activity-meta .activity-user', text: 'John Doe'
      assert_select '.activity-meta .activity-time', text: '2 hours ago'
    end
    
    # Check second activity item
    assert_select '.activity-item:last-child' do
      assert_select '.activity-icon i.fas.fa-user-plus'
      assert_select '.activity-content h4', text: 'New member joined'
      assert_select '.activity-content p', text: 'Jane Smith joined the department'
      assert_select '.activity-meta .activity-user', text: 'Jane Smith'
      assert_select '.activity-meta .activity-time', text: '4 hours ago'
    end
  end

  test "should render date filter controls" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check date input fields
    assert_select '#dateFrom[type="date"]'
    assert_select '#dateTo[type="date"]'
    
    # Check date preset buttons
    assert_select '.date-preset-btn', text: 'Today'
    assert_select '.date-preset-btn', text: 'This Week'
    assert_select '.date-preset-btn', text: 'This Month'
    assert_select '.date-preset-btn', text: 'Clear'
  end

  test "should render user filter dropdown" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check user filter select
    assert_select '#userFilter select'
    assert_select '#userFilter option[value=""]', text: 'All Users'
    
    # Check most active users are listed
    @most_active_users.each do |user|
      assert_select '#userFilter option', text: /#{user['name']}/
    end
  end

  test "should handle empty activity feed" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: [],
             activity_types_summary: {
               'announcements' => 0,
               'content_sharing' => 0,
               'member_changes' => 0,
               'assignments' => 0,
               'quizzes' => 0,
               'notes' => 0
             },
             most_active_users: [],
             has_more: false,
             total_count: 0
           }
    
    # Should show empty state message
    assert_select '#activityFeed:empty' do
      # Empty feed message should be handled by JavaScript
    end
    
    # Activity type filters should show (0) counts
    assert_select 'label', text: /Announcements \(0\)/
    assert_select 'label', text: /Content Sharing \(0\)/
  end

  test "should render load more button when has_more is true" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: true,
             total_count: 50
           }
    
    assert_select '#loadMoreBtn'
    assert_select '#loadMoreBtn:not([style*="display: none"])'
  end

  test "should hide load more button when has_more is false" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Load more button should be hidden or not present
    if response.body.include?('loadMoreBtn')
      assert_select '#loadMoreBtn[style*="display: none"]'
    end
  end

  test "should render activity statistics summary" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 39  # Sum of activity counts
           }
    
    # Check total count display
    assert_select '.total-activities', text: /39/
    
    # Check activity type breakdown
    assert_select '.activity-type-count', count: 6
  end

  test "should include necessary JavaScript functionality" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: true,
             total_count: 25
           }
    
    # Check for JavaScript event handlers and AJAX setup
    assert_match /data-department-id/, response.body
    assert_match /filter-form/, response.body
    assert_match /loadMoreBtn/, response.body
  end

  test "should render with proper CSS classes for styling" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check Tailwind CSS classes are present
    assert_match /bg-white/, response.body
    assert_match /shadow/, response.body
    assert_match /rounded/, response.body
    assert_match /p-6/, response.body
    assert_match /space-y/, response.body
    
    # Check activity-specific styling
    assert_match /activity-item/, response.body
    assert_match /activity-icon/, response.body
    assert_match /activity-content/, response.body
    assert_match /activity-meta/, response.body
  end

  test "should be responsive and mobile-friendly" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check for responsive classes
    assert_match /md:/, response.body  # Medium screen breakpoint
    assert_match /lg:/, response.body  # Large screen breakpoint
    assert_match /sm:/, response.body  # Small screen breakpoint
    
    # Check mobile-specific elements
    assert_match /mobile/, response.body, "Should have mobile-specific styling"
  end

  test "should handle activity links correctly" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check that activity links are rendered
    @activities.each do |activity|
      if activity['url'].present?
        assert_match activity['url'], response.body
      end
    end
  end

  test "should render with proper accessibility attributes" do
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: @activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 2
           }
    
    # Check for accessibility attributes
    assert_select 'label[for]'  # Labels should have 'for' attributes
    assert_select 'input[id]'   # Inputs should have 'id' attributes
    
    # Check for semantic HTML structure
    assert_select 'main, section, article'  # Should use semantic elements
  end

  test "should escape user content properly" do
    # Test with potentially dangerous content
    malicious_activities = [
      {
        'id' => 1,
        'type' => 'content_sharing',
        'title' => '<script>alert("xss")</script>Malicious Title',
        'description' => '<img src="x" onerror="alert(\'xss\')" />Description',
        'user_name' => '<b>Evil User</b>',
        'formatted_time' => '1 hour ago',
        'formatted_date' => Date.today.strftime('%B %d, %Y'),
        'icon' => 'fas fa-share-alt',
        'color' => 'text-blue-600',
        'url' => 'javascript:alert("xss")'
      }
    ]
    
    render template: 'departments/activity/index.html.erb',
           locals: {
             department: @department,
             activities: malicious_activities,
             activity_types_summary: @activity_types_summary,
             most_active_users: @most_active_users,
             has_more: false,
             total_count: 1
           }
    
    # Check that HTML is escaped
    assert_no_match /<script>/, response.body
    assert_no_match /onerror=/, response.body
    assert_no_match /javascript:/, response.body
    
    # Check that content is still displayed (but escaped)
    assert_match /&lt;script&gt;/, response.body
    assert_match /&lt;b&gt;Evil User&lt;\/b&gt;/, response.body
  end
end