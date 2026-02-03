require 'test_helper'

class DepartmentReportsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @department = departments(:computer_science)
    @admin.update(department: @department)
    
    # Create some test data
    create_test_data
  end

  test "complete reports workflow" do
    # Sign in as admin
    sign_in_as(@admin)
    
    # Visit reports dashboard
    get department_reports_path(@department)
    assert_response :success
    assert_select 'h1', /Reports Dashboard/
    
    # Check that all report types are available
    assert_select 'a[href*="member_stats"]'
    assert_select 'a[href*="activity_summary"]'
    assert_select 'a[href*="content_report"]'
    
    # Visit member stats report
    get member_stats_department_reports_path(@department)
    assert_response :success
    assert_select '.member-stats-summary'
    assert_select '.export-buttons'
    
    # Test CSV export
    get send_member_stats_csv_department_reports_path(@department)
    assert_response :success
    assert_equal 'text/csv', response.media_type
    
    # Verify CSV content structure
    csv_content = response.body
    lines = csv_content.split("\n")
    assert lines.length > 1, "CSV should have header and data rows"
    
    # Test PDF export
    get send_member_stats_pdf_department_reports_path(@department)
    assert_response :success
    assert_equal 'application/pdf', response.media_type
    
    # Test Excel export
    get send_member_stats_excel_department_reports_path(@department, format: :xlsx)
    assert_response :success
    assert_match /vnd\.openxmlformats/, response.media_type
    
    # Visit activity summary with date filter
    get activity_summary_department_reports_path(@department, date_range: '7')
    assert_response :success
    assert_select '.activity-timeline'
    
    # Test comprehensive export
    get send_comprehensive_pdf_department_reports_path(@department)
    assert_response :success
    assert_equal 'application/pdf', response.media_type
  end

  test "unauthorized access prevention" do
    # Try to access without signing in
    get department_reports_path(@department)
    assert_redirected_to new_user_session_path
    
    # Sign in as user from different department
    other_user = users(:student)
    other_department = departments(:physics)
    other_user.update(department: other_department)
    
    sign_in_as(other_user)
    get department_reports_path(@department)
    assert_redirected_to departments_path
    assert_match /access/, flash[:alert]
  end

  test "reports with real data calculations" do
    sign_in_as(@admin)
    
    # Get member stats and verify calculations
    get member_stats_department_reports_path(@department)
    assert_response :success
    
    # The view should display correct member counts
    total_members = @department.users.count
    assert_select '.total-members', text: /#{total_members}/
    
    # Test with date range filtering
    get member_stats_department_reports_path(@department, date_range: '30')
    assert_response :success
    
    # Should still show same total members but different recent additions
    assert_select '.total-members', text: /#{total_members}/
  end

  test "export file names and headers" do
    sign_in_as(@admin)
    
    # Test CSV export headers
    get send_member_stats_csv_department_reports_path(@department)
    assert_response :success
    
    disposition = response.headers['Content-Disposition']
    assert_match /attachment/, disposition
    assert_match /#{@department.code}/, disposition
    assert_match /member_stats/, disposition
    assert_match /#{Date.today}/, disposition
    
    # Test PDF export headers
    get send_member_stats_pdf_department_reports_path(@department)
    assert_response :success
    
    disposition = response.headers['Content-Disposition']
    assert_match /attachment/, disposition
    assert_match /\.pdf/, disposition
    
    # Test Excel export headers
    get send_member_stats_excel_department_reports_path(@department, format: :xlsx)
    assert_response :success
    
    disposition = response.headers['Content-Disposition']
    assert_match /attachment/, disposition
    assert_match /\.xlsx/, disposition
  end

  test "error handling for invalid department" do
    sign_in_as(@admin)
    
    # Try to access reports for non-existent department
    assert_raises(ActiveRecord::RecordNotFound) do
      get department_reports_path(99999)
    end
  end

  private

  def create_test_data
    # Create some users for the department
    3.times do |i|
      User.create!(
        email: "testuser#{i}@example.com",
        password: 'password123',
        first_name: "Test#{i}",
        last_name: "User",
        role: 'student',
        department: @department
      )
    end
    
    # Create some content sharing history
    user = @department.users.first
    if user
      ContentSharingHistory.create!(
        shareable_type: 'Assignment',
        shareable_id: 1,
        department: @department,
        shared_by: user,
        action: 'shared'
      )
    end
    
    # Create some member history
    DepartmentMemberHistory.create!(
      user: user,
      department: @department,
      action: 'joined'
    ) if user
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end