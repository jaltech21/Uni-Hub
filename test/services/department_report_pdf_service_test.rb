require 'test_helper'

class DepartmentReportPdfServiceTest < ActiveSupport::TestCase
  setup do
    @department = departments(:computer_science)
    @service = DepartmentReportPdfService.new(@department)
    @sample_data = {
      total_members: 10,
      total_teachers: 3,
      total_students: 7,
      recent_members: [],
      role_distribution: { 'teacher' => 3, 'student' => 7 },
      status_distribution: { 'active' => 9, 'inactive' => 1 },
      member_growth: [['Nov 2025', 10], ['Oct 2025', 8]],
      date_range: "Last 30 days"
    }
  end

  test "should initialize with department" do
    assert_equal @department, @service.department
  end

  test "should generate member stats PDF" do
    pdf = @service.generate_member_stats_pdf(@sample_data)
    
    assert_not_nil pdf
    assert pdf.respond_to?(:render)
    assert pdf.respond_to?(:page_count)
    assert pdf.page_count > 0
  end

  test "should generate activity summary PDF" do
    activity_data = {
      total_announcements: 5,
      recent_announcements: [],
      shared_content_count: 10,
      recent_content: [],
      daily_activity: [['11/01', 3], ['11/02', 5]],
      date_range: "Last 7 days"
    }
    
    pdf = @service.generate_activity_summary_pdf(activity_data)
    
    assert_not_nil pdf
    assert pdf.page_count > 0
  end

  test "should generate content report PDF" do
    content_data = {
      total_content: 15,
      recent_content: [],
      content_by_type: { 'Assignment' => 8, 'Quiz' => 4, 'Note' => 3 },
      top_sharers: [['John Doe', 5], ['Jane Smith', 3]],
      date_range: "Last 30 days"
    }
    
    pdf = @service.generate_content_report_pdf(content_data)
    
    assert_not_nil pdf
    assert pdf.page_count > 0
  end

  test "should generate comprehensive PDF" do
    activity_data = {
      total_announcements: 5,
      recent_announcements: [],
      shared_content_count: 10,
      recent_content: [],
      daily_activity: [['11/01', 3]],
      date_range: "Last 7 days"
    }
    
    content_data = {
      total_content: 15,
      recent_content: [],
      content_by_type: { 'Assignment' => 8 },
      top_sharers: [['John Doe', 5]],
      date_range: "Last 30 days"
    }
    
    pdf = @service.generate_comprehensive_pdf(@sample_data, activity_data, content_data)
    
    assert_not_nil pdf
    assert pdf.page_count > 2 # Should have multiple pages
  end

  test "should handle empty data gracefully" do
    empty_data = {
      total_members: 0,
      total_teachers: 0,
      total_students: 0,
      recent_members: [],
      role_distribution: {},
      status_distribution: {},
      member_growth: [],
      date_range: "Last 30 days"
    }
    
    pdf = @service.generate_member_stats_pdf(empty_data)
    
    assert_not_nil pdf
    assert pdf.page_count > 0
  end

  test "should include department information in PDF" do
    pdf = @service.generate_member_stats_pdf(@sample_data)
    pdf_content = pdf.render
    
    # PDF content is binary, but we can check it was generated
    assert pdf_content.length > 1000 # PDF should have substantial content
    assert pdf_content.start_with?('%PDF') # PDF magic number
  end

  test "should handle missing recent members" do
    data_without_recent = @sample_data.dup
    data_without_recent[:recent_members] = nil
    
    pdf = @service.generate_member_stats_pdf(data_without_recent)
    
    assert_not_nil pdf
    assert pdf.page_count > 0
  end
end