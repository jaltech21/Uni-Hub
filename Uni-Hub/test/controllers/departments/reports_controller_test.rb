require 'test_helper'

class Departments::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @department = departments(:computer_science)
    @user.update(department: @department)
    sign_in @user
  end

  test "should get index" do
    get department_reports_path(@department)
    assert_response :success
    assert_select 'h1', /Reports Dashboard/
    assert_select '.available-reports'
  end

  test "should get member stats" do
    get member_stats_department_reports_path(@department)
    assert_response :success
    assert_select 'h1', /Member Statistics/
    assert_select '.member-stats-summary'
  end

  test "should get activity summary" do
    get activity_summary_department_reports_path(@department)
    assert_response :success
    assert_select 'h1', /Activity Summary/
    assert_select '.activity-timeline'
  end

  test "should get content report" do
    get content_report_department_reports_path(@department)
    assert_response :success
    assert_select 'h1', /Content Report/
    assert_select '.content-breakdown'
  end

  test "should export member stats CSV" do
    get send_member_stats_csv_department_reports_path(@department)
    assert_response :success
    assert_equal 'text/csv', response.media_type
    assert_match /attachment/, response.headers['Content-Disposition']
  end

  test "should export member stats PDF" do
    get send_member_stats_pdf_department_reports_path(@department)
    assert_response :success
    assert_equal 'application/pdf', response.media_type
    assert_match /attachment/, response.headers['Content-Disposition']
  end

  test "should export member stats Excel" do
    get send_member_stats_excel_department_reports_path(@department, format: :xlsx)
    assert_response :success
    assert_match /application\/vnd\.openxmlformats/, response.media_type
    assert_match /attachment/, response.headers['Content-Disposition']
  end

  test "should handle date range filtering" do
    get member_stats_department_reports_path(@department, date_range: '30')
    assert_response :success
    assert_select '.date-filter'
  end

  test "should require authentication" do
    sign_out @user
    get department_reports_path(@department)
    assert_redirected_to new_user_session_path
  end

  test "should require department membership" do
    other_department = departments(:physics)
    get department_reports_path(other_department)
    assert_redirected_to departments_path
    assert_match /access/, flash[:alert]
  end

  test "should generate comprehensive PDF" do
    get send_comprehensive_pdf_department_reports_path(@department)
    assert_response :success
    assert_equal 'application/pdf', response.media_type
  end

  test "should generate comprehensive Excel" do
    get send_comprehensive_excel_department_reports_path(@department, format: :xlsx)
    assert_response :success
    assert_match /application\/vnd\.openxmlformats/, response.media_type
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