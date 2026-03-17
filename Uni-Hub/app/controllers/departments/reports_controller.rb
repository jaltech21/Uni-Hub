class Departments::ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_department
  before_action :authorize_report_access
  
  # GET /departments/:department_id/reports
  def index
    @available_reports = [
      {
        name: 'Member Statistics',
        description: 'Overview of department membership, roles, and status',
        icon: '👥',
        path: member_stats_department_reports_path(@department)
      },
      {
        name: 'Activity Summary',
        description: 'Recent announcements, content, and member activity',
        icon: '📊',
        path: activity_summary_department_reports_path(@department)
      },
      {
        name: 'Content Report',
        description: 'Analysis of shared content and engagement',
        icon: '📄',
        path: content_report_department_reports_path(@department)
      },
      {
        name: 'Member History',
        description: 'Complete timeline of member changes',
        icon: '📅',
        path: history_department_members_path(@department)
      }
    ]
  end
  
  # GET /departments/:department_id/reports/member_stats
  def member_stats
    @report_date = Time.current
    @date_range = params[:date_range] || '30' # days
    @start_date = @date_range.to_i.days.ago
    
    # Member statistics
    @total_members = @department.member_count
    @active_members = @department.active_members.count
    @teachers = @department.user_departments.teachers.active.count
    @admins = @department.user_departments.admins.active.count
    @students = @department.users.count
    
    # Role distribution
    @role_distribution = {
      'Teachers' => @teachers,
      'Students' => @students,
      'Members' => @department.user_departments.members.active.count,
      'Admins' => @admins
    }
    
    # Status distribution
    @status_distribution = {
      'Active' => @department.user_departments.active.count,
      'Inactive' => @department.user_departments.inactive.count,
      'Pending' => @department.user_departments.pending.count
    }
    
    # Recent additions (last 30 days)
    @recent_additions = @department.user_departments
      .where('joined_at >= ?', @start_date)
      .order(joined_at: :desc)
    
    # Member growth over time (last 6 months)
    @member_growth = calculate_member_growth
    
    respond_to do |format|
      format.html
      format.csv { send_member_stats_csv }
      format.pdf { send_member_stats_pdf }
    end
  end
  
  # GET /departments/:department_id/reports/activity_summary
  def activity_summary
    @report_date = Time.current
    @date_range = params[:date_range] || '30'
    @start_date = @date_range.to_i.days.ago
    
    # Announcements statistics
    @total_announcements = @department.announcements.count
    @recent_announcements = @department.announcements
      .where('created_at >= ?', @start_date)
      .order(created_at: :desc)
      .limit(10)
    @published_announcements = @department.announcements.published.count
    @pinned_announcements = @department.announcements.where(pinned: true).count
    
    # Content sharing statistics
    @total_shared_content = ContentSharingHistory.where(department: @department).count
    @recent_content = ContentSharingHistory.where(department: @department)
      .where('created_at >= ?', @start_date)
      .includes(:shared_by, :shareable)
      .order(created_at: :desc)
      .limit(10)
    
    # Member activity
    @member_changes = @department.department_member_histories
      .where('created_at >= ?', @start_date)
      .count
    @new_members = @department.department_member_histories
      .where(action: 'added')
      .where('created_at >= ?', @start_date)
      .count
    
    # Activity by day
    @activity_by_day = calculate_activity_by_day(@start_date)
    
    respond_to do |format|
      format.html
      format.csv { send_activity_summary_csv }
      format.pdf { send_activity_summary_pdf }
    end
  end
  
  # GET /departments/:department_id/reports/content_report
  def content_report
    @report_date = Time.current
    @date_range = params[:date_range] || '30'
    @start_date = @date_range.to_i.days.ago
    
    # Content statistics
    @total_content = ContentSharingHistory.where(department: @department).count
    @recent_content = ContentSharingHistory.where(department: @department)
      .where('created_at >= ?', @start_date)
      .includes(:shared_by, :shareable)
      .order(created_at: :desc)
    
    # Content by type
    @content_by_type = ContentSharingHistory.where(department: @department)
      .where('created_at >= ?', @start_date)
      .group(:shareable_type)
      .count
    
    # Most active sharers
    @top_sharers = ContentSharingHistory.where(department: @department)
      .where('created_at >= ?', @start_date)
      .joins(:shared_by)
      .group('users.id', 'users.first_name', 'users.last_name')
      .select('users.id, users.first_name, users.last_name, COUNT(*) as share_count')
      .order('share_count DESC')
      .limit(10)
    
    respond_to do |format|
      format.html
      format.csv { send_content_report_csv }
      format.pdf { send_content_report_pdf }
    end
  end
  
  # GET /departments/:department_id/reports/export_all
  def export_all
    @report_date = Time.current
    
    respond_to do |format|
      format.pdf do
        pdf = generate_comprehensive_pdf
        send_data pdf.render,
          filename: "#{@department.code}_comprehensive_report_#{Date.today}.pdf",
          type: 'application/pdf',
          disposition: 'attachment'
      end
    end
  end
  
  private
  
  def set_department
    @department = Department.find(params[:department_id])
  end
  
  def authorize_report_access
    unless current_user.admin? || 
           @department.user_departments.where(user: current_user, role: ['teacher', 'admin']).exists?
      flash[:alert] = "You are not authorized to view reports for this department."
      redirect_to root_path
    end
  end
  
  def calculate_member_growth
    growth = {}
    6.downto(0) do |i|
      date = i.months.ago.beginning_of_month
      count = @department.user_departments.where('joined_at <= ?', date.end_of_month).count +
              @department.users.where('created_at <= ?', date.end_of_month).count
      growth[date.strftime('%b %Y')] = count
    end
    growth
  end
  
  def calculate_activity_by_day(start_date)
    activity = {}
    (start_date.to_date..Date.today).each do |date|
      announcements = @department.announcements.where('DATE(created_at) = ?', date).count
      content = ContentSharingHistory.where(department: @department).where('DATE(created_at) = ?', date).count
      member_changes = @department.department_member_histories.where('DATE(created_at) = ?', date).count
      
      activity[date.strftime('%m/%d')] = announcements + content + member_changes
    end
    activity
  end
  
  def send_member_stats_csv
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Department Member Statistics', @department.name, Date.today]
      csv << []
      csv << ['Metric', 'Count']
      csv << ['Total Members', @total_members]
      csv << ['Active Members', @active_members]
      csv << ['Teachers', @teachers]
      csv << ['Students', @students]
      csv << ['Admins', @admins]
      csv << []
      csv << ['Recent Additions (Last 30 Days)']
      csv << ['Name', 'Email', 'Role', 'Status', 'Joined Date']
      
      @recent_additions.each do |member|
        csv << [
          member.user.full_name,
          member.user.email,
          member.role,
          member.status,
          member.joined_at&.strftime('%Y-%m-%d')
        ]
      end
    end
    
    send_data csv_data,
      filename: "#{@department.code}_member_stats_#{Date.today}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end
  
  def send_activity_summary_csv
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Department Activity Summary', @department.name, Date.today]
      csv << []
      csv << ['Announcements']
      csv << ['Title', 'Status', 'Created', 'Author']
      
      @recent_announcements.each do |announcement|
        csv << [
          announcement.title,
          announcement.published? ? 'Published' : 'Draft',
          announcement.created_at.strftime('%Y-%m-%d %H:%M'),
          announcement.user.full_name
        ]
      end
      
      csv << []
      csv << ['Shared Content']
      csv << ['Type', 'Shared By', 'Date', 'Permission']
      
      @recent_content.each do |content|
        csv << [
          content.shareable_type,
          content.shared_by.full_name,
          content.created_at.strftime('%Y-%m-%d %H:%M'),
          content.action
        ]
      end
    end
    
    send_data csv_data,
      filename: "#{@department.code}_activity_summary_#{Date.today}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end
  
  def send_content_report_csv
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Department Content Report', @department.name, Date.today]
      csv << []
      csv << ['Content Item', 'Type', 'Shared By', 'Date', 'Permission']
      
      @recent_content.each do |content|
        csv << [
          content.shareable&.respond_to?(:title) ? content.shareable.title : "#{content.shareable_type} ##{content.shareable_id}",
          content.shareable_type,
          content.shared_by.full_name,
          content.created_at.strftime('%Y-%m-%d %H:%M'),
          content.action
        ]
      end
      
      csv << []
      csv << ['Top Content Sharers']
      csv << ['Name', 'Share Count']
      
      @top_sharers.each do |sharer|
        csv << [
          "#{sharer.first_name} #{sharer.last_name}",
          sharer.share_count
        ]
      end
    end
    
    send_data csv_data,
      filename: "#{@department.code}_content_report_#{Date.today}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end
  
  def send_member_stats_pdf
    pdf_service = DepartmentReportPdfService.new(@department)
    
    data = {
      total_members: @total_members,
      active_members: @active_members,
      teachers: @teachers,
      students: @students,
      admins: @admins,
      role_distribution: @role_distribution,
      status_distribution: @status_distribution,
      recent_additions: @recent_additions,
      member_growth: @member_growth,
      date_range: @date_range
    }
    
    pdf = pdf_service.generate_member_stats_pdf(data)
    
    send_data pdf.render,
      filename: "#{@department.code}_member_stats_#{Date.today}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
  end
  
  def send_activity_summary_pdf
    pdf_service = DepartmentReportPdfService.new(@department)
    
    data = {
      total_announcements: @total_announcements,
      recent_announcements: @recent_announcements,
      published_announcements: @published_announcements,
      pinned_announcements: @pinned_announcements,
      total_shared_content: @total_shared_content,
      recent_content: @recent_content,
      member_changes: @member_changes,
      new_members: @new_members,
      activity_by_day: @activity_by_day,
      date_range: @date_range
    }
    
    pdf = pdf_service.generate_activity_summary_pdf(data)
    
    send_data pdf.render,
      filename: "#{@department.code}_activity_summary_#{Date.today}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
  end
  
  def send_content_report_pdf
    pdf_service = DepartmentReportPdfService.new(@department)
    
    data = {
      total_content: @total_content,
      recent_content: @recent_content,
      content_by_type: @content_by_type,
      top_sharers: @top_sharers,
      date_range: @date_range
    }
    
    pdf = pdf_service.generate_content_report_pdf(data)
    
    send_data pdf.render,
      filename: "#{@department.code}_content_report_#{Date.today}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
  end
  
  def send_comprehensive_pdf
    pdf_service = DepartmentReportPdfService.new(@department)
    
    # Gather all report data
    load_member_stats_data
    load_activity_summary_data
    load_content_report_data
    
    member_data = {
      total_members: @total_members,
      total_teachers: @total_teachers,
      total_students: @total_students,
      recent_members: @recent_members,
      role_distribution: @members_by_role,
      status_distribution: @members_by_status,
      member_growth: @member_growth,
      date_range: @date_range
    }
    
    activity_data = {
      total_announcements: @total_announcements,
      recent_announcements: @recent_announcements,
      shared_content_count: @shared_content_count,
      recent_content: @recent_content,
      daily_activity: @daily_activity,
      date_range: @date_range
    }
    
    content_data = {
      total_content: @total_content,
      recent_content: @recent_content,
      content_by_type: @content_by_type,
      top_sharers: @top_sharers,
      date_range: @date_range
    }
    
    pdf = pdf_service.generate_comprehensive_pdf(member_data, activity_data, content_data)
    
    send_data pdf.render,
      filename: "#{@department.code}_comprehensive_report_#{Date.today}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
  end

  # Excel Export Methods
  def send_member_stats_excel
    load_member_stats_data
    
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"#{@department.code}_member_stats_#{Date.today}.xlsx\""
      }
    end
  end
  
  def send_activity_summary_excel
    load_activity_summary_data
    
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"#{@department.code}_activity_summary_#{Date.today}.xlsx\""
      }
    end
  end
  
  def send_content_report_excel
    load_content_report_data
    
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"#{@department.code}_content_report_#{Date.today}.xlsx\""
      }
    end
  end
  
  def send_comprehensive_excel
    load_member_stats_data
    load_activity_summary_data
    load_content_report_data
    
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"#{@department.code}_comprehensive_report_#{Date.today}.xlsx\""
      }
    end
  end
end
