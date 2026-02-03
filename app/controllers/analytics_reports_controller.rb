class AnalyticsReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_analytics_report, only: [:show, :edit, :update, :destroy, :export, :regenerate]
  before_action :authorize_report_access, only: [:show, :edit, :update, :destroy, :export]
  
  def index
    @reports = current_user.analytics_reports.recent.includes(:department, :analytics_dashboard)
    @reports = @reports.by_type(params[:type]) if params[:type].present?
    @reports = @reports.by_status(params[:status]) if params[:status].present?
    @reports = @reports.page(params[:page]).per(20)
    
    @report_types = AnalyticsReport.distinct.pluck(:report_type)
    @report_statuses = ['draft', 'generating', 'completed', 'failed', 'scheduled']
    
    respond_to do |format|
      format.html
      format.json { render json: @reports.as_json(include: [:department, :analytics_dashboard]) }
    end
  end
  
  def show
    @summary_stats = @analytics_report.summary_stats
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics_report.as_json(include: :summary_stats) }
    end
  end
  
  def new
    @analytics_report = current_user.analytics_reports.build
    @report_types = get_available_report_types
    @departments = get_available_departments
    @dashboards = current_user.analytics_dashboards.active
  end
  
  def create
    @analytics_report = current_user.analytics_reports.build(report_params)
    @analytics_report.status = 'draft'
    
    if @analytics_report.save
      # Generate report immediately or queue for background processing
      if params[:generate_immediately]
        GenerateReportJob.perform_later(@analytics_report.id)
        redirect_to @analytics_report, notice: 'Report is being generated. You will be notified when complete.'
      else
        redirect_to @analytics_report, notice: 'Report was successfully created.'
      end
    else
      @report_types = get_available_report_types
      @departments = get_available_departments
      @dashboards = current_user.analytics_dashboards.active
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @report_types = get_available_report_types
    @departments = get_available_departments
    @dashboards = current_user.analytics_dashboards.active
  end
  
  def update
    if @analytics_report.update(report_params)
      redirect_to @analytics_report, notice: 'Report was successfully updated.'
    else
      @report_types = get_available_report_types
      @departments = get_available_departments
      @dashboards = current_user.analytics_dashboards.active
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @analytics_report.destroy!
    redirect_to analytics_reports_url, notice: 'Report was successfully deleted.'
  end
  
  def generate
    @analytics_report = current_user.analytics_reports.find(params[:id])
    
    if @analytics_report.status == 'generating'
      redirect_to @analytics_report, alert: 'Report is already being generated.'
      return
    end
    
    GenerateReportJob.perform_later(@analytics_report.id)
    redirect_to @analytics_report, notice: 'Report generation started. You will be notified when complete.'
  end
  
  def regenerate
    if @analytics_report.status == 'generating'
      redirect_to @analytics_report, alert: 'Report is already being generated.'
      return
    end
    
    @analytics_report.update!(status: 'draft', data: nil, error_message: nil)
    GenerateReportJob.perform_later(@analytics_report.id)
    redirect_to @analytics_report, notice: 'Report is being regenerated.'
  end
  
  def export
    format = params[:format] || 'pdf'
    
    unless @analytics_report.completed?
      redirect_to @analytics_report, alert: 'Report must be completed before export.'
      return
    end
    
    begin
      exported_data = @analytics_report.export(format: format)
      
      case format.downcase
      when 'pdf'
        send_data exported_data, filename: "#{@analytics_report.title}.pdf", type: 'application/pdf'
      when 'excel'
        send_data exported_data, filename: "#{@analytics_report.title}.xlsx", 
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      when 'csv'
        send_data exported_data, filename: "#{@analytics_report.title}.csv", type: 'text/csv'
      when 'json'
        send_data exported_data, filename: "#{@analytics_report.title}.json", type: 'application/json'
      else
        redirect_to @analytics_report, alert: 'Unsupported export format.'
      end
    rescue StandardError => e
      redirect_to @analytics_report, alert: "Export failed: #{e.message}"
    end
  end
  
  def schedule
    frequency = params[:frequency] || 'weekly'
    config = {
      report_type: params[:report_type],
      title: params[:title],
      filters: params[:filters] || {},
      config: params[:config] || {}
    }
    
    scheduled_report = AnalyticsReport.schedule_report(
      user: current_user,
      config: config,
      frequency: frequency
    )
    
    if scheduled_report.persisted?
      redirect_to analytics_reports_path, notice: 'Report scheduled successfully.'
    else
      redirect_to new_analytics_report_path, alert: 'Failed to schedule report.'
    end
  end
  
  def preview
    @analytics_report = current_user.analytics_reports.build(report_params)
    
    # Generate a preview with limited data
    preview_data = generate_report_preview(@analytics_report)
    
    respond_to do |format|
      format.json { render json: { success: true, preview: preview_data } }
      format.html { render :preview, locals: { preview_data: preview_data } }
    end
  end
  
  def templates
    @templates = get_report_templates_for_user
    
    respond_to do |format|
      format.json { render json: @templates }
      format.html
    end
  end
  
  def create_from_template
    template = params[:template]
    template_config = get_template_config(template)
    
    if template_config
      @analytics_report = current_user.analytics_reports.build(template_config)
      @analytics_report.title = "#{template_config[:title]} - #{Date.current.strftime('%B %Y')}"
      
      if @analytics_report.save
        redirect_to @analytics_report, notice: 'Report created from template successfully.'
      else
        redirect_to new_analytics_report_path, alert: 'Failed to create report from template.'
      end
    else
      redirect_to new_analytics_report_path, alert: 'Template not found.'
    end
  end
  
  # AJAX endpoints
  def status
    render json: { 
      status: @analytics_report.status,
      progress: calculate_progress(@analytics_report),
      estimated_completion: estimate_completion_time(@analytics_report)
    }
  end
  
  def cancel_generation
    if @analytics_report.status == 'generating'
      # Cancel the background job if possible
      @analytics_report.update!(status: 'draft')
      render json: { success: true, message: 'Report generation cancelled.' }
    else
      render json: { success: false, message: 'Cannot cancel report that is not being generated.' }
    end
  end
  
  private
  
  def set_analytics_report
    @analytics_report = AnalyticsReport.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to analytics_reports_url, alert: 'Report not found.'
  end
  
  def authorize_report_access
    unless @analytics_report.user == current_user || 
           current_user.role == 'admin' ||
           (@analytics_report.department && current_user.department == @analytics_report.department)
      redirect_to analytics_reports_url, alert: 'Access denied.'
    end
  end
  
  def report_params
    params.require(:analytics_report).permit(
      :title, :report_type, :department_id, :analytics_dashboard_id,
      config: {}, filters: {}, metadata: {}
    )
  end
  
  def get_available_report_types
    types = []
    
    case current_user.role
    when 'student'
      types += ['student_performance']
    when 'teacher'
      types += ['class_analytics', 'assignment_summary', 'attendance_report', 'student_performance']
    when 'admin'
      types += ['institutional_metrics', 'department_overview', 'class_analytics', 
                'assignment_summary', 'attendance_report', 'student_performance', 'custom_report']
    end
    
    types << 'scheduled_report' if current_user.role.in?(['teacher', 'admin'])
    types
  end
  
  def get_available_departments
    case current_user.role
    when 'admin'
      Department.active.ordered
    when 'teacher', 'student'
      current_user.department ? [current_user.department] : []
    else
      []
    end
  end
  
  def generate_report_preview(report)
    # Generate a limited preview of the report data
    case report.report_type
    when 'student_performance'
      {
        sample_students: 3,
        metrics: ['overall_grade', 'attendance_rate', 'assignment_completion'],
        time_range: '30 days',
        estimated_records: User.where(role: 'student').count
      }
    when 'class_analytics'
      {
        sample_classes: 5,
        metrics: ['enrollment', 'attendance_rate', 'average_grade'],
        time_range: params.dig(:filters, :time_range) || '30 days',
        estimated_records: Schedule.count
      }
    when 'attendance_report'
      {
        sample_days: 7,
        metrics: ['daily_attendance', 'late_arrivals', 'attendance_rate'],
        estimated_records: AttendanceRecord.count
      }
    else
      { message: 'Preview not available for this report type' }
    end
  end
  
  def get_report_templates_for_user
    templates = []
    
    case current_user.role
    when 'student'
      templates += [
        {
          id: 'my_performance',
          title: 'My Academic Performance',
          description: 'Comprehensive overview of your academic progress',
          report_type: 'student_performance',
          estimated_time: '2-3 minutes'
        }
      ]
    when 'teacher'
      templates += [
        {
          id: 'class_overview',
          title: 'Class Performance Overview',
          description: 'Summary of all your classes and student performance',
          report_type: 'class_analytics',
          estimated_time: '5-10 minutes'
        },
        {
          id: 'assignment_analysis',
          title: 'Assignment Analysis Report',
          description: 'Detailed analysis of assignment performance and trends',
          report_type: 'assignment_summary',
          estimated_time: '3-5 minutes'
        },
        {
          id: 'attendance_summary',
          title: 'Attendance Summary',
          description: 'Comprehensive attendance patterns and insights',
          report_type: 'attendance_report',
          estimated_time: '2-4 minutes'
        }
      ]
    when 'admin'
      templates += [
        {
          id: 'institutional_dashboard',
          title: 'Institutional Dashboard',
          description: 'University-wide metrics and key performance indicators',
          report_type: 'institutional_metrics',
          estimated_time: '10-15 minutes'
        },
        {
          id: 'department_comparison',
          title: 'Department Comparison Report',
          description: 'Compare performance across all departments',
          report_type: 'department_overview',
          estimated_time: '8-12 minutes'
        }
      ]
    end
    
    templates
  end
  
  def get_template_config(template_id)
    template_configs = {
      'my_performance' => {
        title: 'My Academic Performance',
        report_type: 'student_performance',
        filters: { time_range: '90_days' },
        config: { include_trends: true, include_recommendations: true }
      },
      'class_overview' => {
        title: 'Class Performance Overview',
        report_type: 'class_analytics',
        filters: { time_range: '60_days' },
        config: { include_engagement: true, include_comparisons: true }
      },
      'assignment_analysis' => {
        title: 'Assignment Analysis Report',
        report_type: 'assignment_summary',
        filters: { time_range: '90_days' },
        config: { include_grade_distribution: true, include_timing_analysis: true }
      },
      'attendance_summary' => {
        title: 'Attendance Summary',
        report_type: 'attendance_report',
        filters: { time_range: '60_days' },
        config: { include_patterns: true, include_late_analysis: true }
      },
      'institutional_dashboard' => {
        title: 'Institutional Dashboard',
        report_type: 'institutional_metrics',
        filters: { time_range: '180_days' },
        config: { include_trends: true, include_comparisons: true, include_health_metrics: true }
      },
      'department_comparison' => {
        title: 'Department Comparison Report',
        report_type: 'department_overview',
        filters: { time_range: '120_days' },
        config: { include_all_departments: true, include_rankings: true }
      }
    }
    
    template_configs[template_id]
  end
  
  def calculate_progress(report)
    case report.status
    when 'draft'
      0
    when 'generating'
      # Estimate based on time elapsed
      if report.started_at
        elapsed = Time.current - report.started_at
        estimated_total = estimate_total_time(report)
        [(elapsed / estimated_total * 100).round, 95].min
      else
        10
      end
    when 'completed'
      100
    when 'failed'
      0
    else
      0
    end
  end
  
  def estimate_completion_time(report)
    return nil unless report.status == 'generating' && report.started_at
    
    elapsed = Time.current - report.started_at
    estimated_total = estimate_total_time(report)
    remaining = estimated_total - elapsed
    
    [remaining, 0].max.seconds.from_now
  end
  
  def estimate_total_time(report)
    # Estimate based on report type and data volume
    case report.report_type
    when 'student_performance'
      120.seconds # 2 minutes
    when 'class_analytics'
      300.seconds # 5 minutes
    when 'attendance_report'
      180.seconds # 3 minutes
    when 'assignment_summary'
      240.seconds # 4 minutes
    when 'department_overview'
      600.seconds # 10 minutes
    when 'institutional_metrics'
      900.seconds # 15 minutes
    else
      300.seconds # 5 minutes default
    end
  end
end