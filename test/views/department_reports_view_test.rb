require 'test_helper'

class DepartmentReportsViewTest < ActionView::TestCase
  include ApplicationHelper
  
  setup do
    @department = departments(:computer_science)
    @admin = users(:admin)
    @admin.update(department: @department)
    
    # Mock report data
    @basic_data = {
      total_users: 45,
      active_users: 38,
      total_content: 156,
      recent_activity: 23
    }
    
    @detailed_data = {
      user_stats: [
        { name: 'John Doe', role: 'teacher', activity_count: 25, last_active: '2 hours ago' },
        { name: 'Jane Smith', role: 'student', activity_count: 18, last_active: '1 day ago' }
      ],
      content_stats: [
        { type: 'Assignments', count: 45, recent: 12 },
        { type: 'Quizzes', count: 23, recent: 5 },
        { type: 'Notes', count: 67, recent: 8 }
      ],
      activity_timeline: [
        { date: Date.today.strftime('%Y-%m-%d'), count: 12 },
        { date: 1.day.ago.strftime('%Y-%m-%d'), count: 8 },
        { date: 2.days.ago.strftime('%Y-%m-%d'), count: 15 }
      ]
    }
    
    @summary_data = {
      overview: 'Department performing well with high user engagement',
      key_metrics: [
        'User engagement: 84%',
        'Content creation: +15% this month',
        'Activity trend: Increasing'
      ],
      recommendations: [
        'Continue current engagement strategies',
        'Focus on quiz creation training',
        'Monitor inactive users'
      ]
    }
  end

  test "should render reports index page" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check main structure
    assert_select 'h1', text: /Department Reports/
    assert_select '.report-section', count: 3
    
    # Check report type sections
    assert_select '#basicReport'
    assert_select '#detailedReport' 
    assert_select '#summaryReport'
    
    # Check export buttons
    assert_select '.export-buttons'
    assert_select 'button[data-format="csv"]'
    assert_select 'button[data-format="pdf"]'
    assert_select 'button[data-format="excel"]'
  end

  test "should render basic report section" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check basic report structure
    assert_select '#basicReport' do
      assert_select 'h2', text: /Basic Overview/
      assert_select '.metric-card', count: 4
      assert_select '.generate-btn[data-type="basic"]'
    end
    
    # Check metric placeholders
    assert_select '.metric-card .metric-label', text: /Total Users/
    assert_select '.metric-card .metric-label', text: /Active Users/
    assert_select '.metric-card .metric-label', text: /Total Content/
    assert_select '.metric-card .metric-label', text: /Recent Activity/
  end

  test "should render detailed report section" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check detailed report structure
    assert_select '#detailedReport' do
      assert_select 'h2', text: /Detailed Analysis/
      assert_select '.report-subsection', count: 3
      assert_select '.generate-btn[data-type="detailed"]'
    end
    
    # Check subsection placeholders
    assert_select '.report-subsection h3', text: /User Statistics/
    assert_select '.report-subsection h3', text: /Content Breakdown/
    assert_select '.report-subsection h3', text: /Activity Timeline/
  end

  test "should render summary report section" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check summary report structure
    assert_select '#summaryReport' do
      assert_select 'h2', text: /Executive Summary/
      assert_select '.summary-content'
      assert_select '.generate-btn[data-type="summary"]'
    end
    
    # Check summary placeholders
    assert_select '.summary-content .overview-placeholder'
    assert_select '.summary-content .metrics-placeholder'
    assert_select '.summary-content .recommendations-placeholder'
  end

  test "should render export controls" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check export section
    assert_select '.export-section' do
      assert_select 'h3', text: /Export Options/
      assert_select '.export-buttons'
    end
    
    # Check individual export buttons
    assert_select '.export-btn[data-format="csv"]', text: /CSV/
    assert_select '.export-btn[data-format="pdf"]', text: /PDF/
    assert_select '.export-btn[data-format="excel"]', text: /Excel/
    
    # Check export buttons have proper attributes
    assert_select 'button[data-department-id]'
    assert_select 'button[data-format]'
  end

  test "should render date range selector" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check date range controls
    assert_select '.date-range-selector' do
      assert_select '#startDate[type="date"]'
      assert_select '#endDate[type="date"]'
      assert_select '.date-preset-btn', count: 4
    end
    
    # Check date presets
    assert_select '.date-preset-btn', text: 'Last 7 Days'
    assert_select '.date-preset-btn', text: 'Last 30 Days'
    assert_select '.date-preset-btn', text: 'Last 3 Months'
    assert_select '.date-preset-btn', text: 'Custom Range'
  end

  test "should render loading states" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check loading indicators are present (initially hidden)
    assert_select '.loading-indicator', count: 3
    assert_select '#basicReportLoading[style*="display: none"]'
    assert_select '#detailedReportLoading[style*="display: none"]'
    assert_select '#summaryReportLoading[style*="display: none"]'
  end

  test "should include necessary JavaScript functionality" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check for JavaScript setup
    assert_match /data-department-id/, response.body
    assert_match /generate-btn/, response.body
    assert_match /export-btn/, response.body
    
    # Check for AJAX endpoints references
    assert_match /reports/, response.body
  end

  test "should render with proper CSS styling" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check Tailwind CSS classes
    assert_match /bg-white/, response.body
    assert_match /shadow/, response.body
    assert_match /rounded/, response.body
    assert_match /p-6/, response.body
    assert_match /mb-6/, response.body
    
    # Check report-specific styling
    assert_match /report-section/, response.body
    assert_match /metric-card/, response.body
    assert_match /export-buttons/, response.body
  end

  test "should be responsive and mobile-friendly" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check for responsive classes
    assert_match /md:/, response.body
    assert_match /lg:/, response.body
    assert_match /sm:/, response.body
    
    # Check grid layouts
    assert_match /grid/, response.body
    assert_match /col-span/, response.body
  end

  test "should handle empty or error states" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check error state elements are present (initially hidden)
    assert_select '.error-message', count: 3
    assert_select '.empty-state', count: 3
    
    # Error messages should be hidden initially
    assert_select '.error-message[style*="display: none"]'
  end

  test "should render accessibility features" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check for accessibility attributes
    assert_select 'label[for]'
    assert_select 'input[id]'
    assert_select 'button[aria-label], button[title]'
    
    # Check semantic HTML
    assert_select 'main, section, article'
    assert_select 'h1, h2, h3'
  end

  test "should include proper meta information" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check department information is displayed
    assert_match @department.name, response.body
    assert_match @department.code, response.body
    
    # Check current date/time context
    assert_match Date.today.year.to_s, response.body
  end

  test "should render chart containers" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check chart containers for data visualization
    assert_select '.chart-container', minimum: 2
    assert_select '#userActivityChart'
    assert_select '#contentBreakdownChart'
    assert_select '#activityTimelineChart'
  end

  test "should handle different user permissions" do
    # Test with admin user (should see all options)
    @admin.update(role: 'admin')
    
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # All report sections should be visible for admin
    assert_select '.report-section', count: 3
    assert_select '.export-btn', count: 3
    
    # Test note: In a real implementation, you might conditionally
    # render different sections based on user role
  end

  test "should include proper form security" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check for CSRF protection if forms are present
    if response.body.include?('<form')
      assert_match /authenticity_token/, response.body
    end
    
    # Check data attributes are properly escaped
    assert_no_match /"[^"]*javascript:/, response.body
    assert_no_match /'[^']*javascript:/, response.body
  end

  test "should render progress indicators" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check progress bars for metrics
    assert_select '.progress-bar', minimum: 1
    assert_select '.progress-indicator'
    
    # Check percentage displays
    assert_select '.percentage', minimum: 1
  end

  test "should include help text and tooltips" do
    render template: 'departments/reports/index.html.erb',
           locals: {
             department: @department
           }
    
    # Check for help icons or text
    assert_select '.help-icon, .tooltip, [title]', minimum: 3
    
    # Check for explanatory text
    assert_match /This report shows/, response.body
    assert_match /Click to generate/, response.body
  end
end