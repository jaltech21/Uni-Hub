class AnalyticsDashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_analytics_dashboard, only: [:show, :edit, :update, :destroy, :duplicate]
  before_action :authorize_dashboard_access, only: [:show, :edit, :update, :destroy]
  
  def index
    @dashboards = current_user.analytics_dashboards.active.includes(:dashboard_widgets)
    @default_dashboards = get_default_dashboards_for_user
    @dashboard_types = get_available_dashboard_types
    
    respond_to do |format|
      format.html
      format.json { render json: { dashboards: @dashboards, defaults: @default_dashboards } }
    end
  end
  
  def show
    @dashboard_data = @analytics_dashboard.dashboard_data(time_range: params[:time_range]&.to_i&.days || 30.days)
    @widgets = @analytics_dashboard.dashboard_widgets.active.ordered
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end
  
  def new
    @analytics_dashboard = current_user.analytics_dashboards.build
    @dashboard_types = get_available_dashboard_types
    @widget_templates = DashboardWidget::WIDGET_TEMPLATES
  end
  
  def create
    @analytics_dashboard = current_user.analytics_dashboards.build(dashboard_params)
    @analytics_dashboard.department = current_user.department if current_user.department
    
    if @analytics_dashboard.save
      # Initialize with default layout
      @analytics_dashboard.initialize_default_layout
      @analytics_dashboard.save!
      
      # Create default widgets based on dashboard type
      create_default_widgets(@analytics_dashboard)
      
      redirect_to @analytics_dashboard, notice: 'Analytics dashboard was successfully created.'
    else
      @dashboard_types = get_available_dashboard_types
      @widget_templates = DashboardWidget::WIDGET_TEMPLATES
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @dashboard_types = get_available_dashboard_types
    @widget_templates = DashboardWidget::WIDGET_TEMPLATES
    @available_widgets = @analytics_dashboard.dashboard_widgets.active
  end
  
  def update
    if @analytics_dashboard.update(dashboard_params)
      redirect_to @analytics_dashboard, notice: 'Analytics dashboard was successfully updated.'
    else
      @dashboard_types = get_available_dashboard_types
      @widget_templates = DashboardWidget::WIDGET_TEMPLATES
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @analytics_dashboard.destroy!
    redirect_to analytics_dashboards_url, notice: 'Analytics dashboard was successfully deleted.'
  end
  
  def duplicate
    new_dashboard = @analytics_dashboard.dup
    new_dashboard.title = "Copy of #{@analytics_dashboard.title}"
    new_dashboard.user = current_user
    
    if new_dashboard.save
      # Duplicate widgets
      @analytics_dashboard.dashboard_widgets.each do |widget|
        new_widget = widget.dup
        new_widget.analytics_dashboard = new_dashboard
        new_widget.save
      end
      
      redirect_to new_dashboard, notice: 'Dashboard successfully duplicated.'
    else
      redirect_to @analytics_dashboard, alert: 'Failed to duplicate dashboard.'
    end
  end
  
  # AJAX endpoints for dashboard management
  def widget_data
    widget_type = params[:widget_type]
    time_range = params[:time_range]&.to_i&.days || 30.days
    
    if @analytics_dashboard
      data = @analytics_dashboard.send(:generate_widget_data, widget_type, time_range)
      render json: { success: true, data: data }
    else
      render json: { success: false, error: 'Dashboard not found' }
    end
  end
  
  def update_layout
    if @analytics_dashboard.update(layout_config: params[:layout_config])
      render json: { success: true }
    else
      render json: { success: false, errors: @analytics_dashboard.errors }
    end
  end
  
  def add_widget
    widget_type = params[:widget_type]
    position = params[:position] || {}
    
    widget = DashboardWidget.create_from_template(@analytics_dashboard, widget_type, position)
    
    if widget
      render json: { 
        success: true, 
        widget: widget.as_json(include: :analytics_dashboard),
        data: widget.widget_data
      }
    else
      render json: { success: false, error: 'Failed to create widget' }
    end
  end
  
  def remove_widget
    widget = @analytics_dashboard.dashboard_widgets.find(params[:widget_id])
    
    if widget.destroy
      render json: { success: true }
    else
      render json: { success: false, error: 'Failed to remove widget' }
    end
  end
  
  def export_dashboard
    format = params[:format] || 'pdf'
    
    case format
    when 'pdf'
      pdf_data = generate_dashboard_pdf(@analytics_dashboard)
      send_data pdf_data, filename: "#{@analytics_dashboard.title}.pdf", type: 'application/pdf'
    when 'excel'
      excel_data = generate_dashboard_excel(@analytics_dashboard)
      send_data excel_data, filename: "#{@analytics_dashboard.title}.xlsx", 
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'json'
      data = @analytics_dashboard.dashboard_data
      send_data data.to_json, filename: "#{@analytics_dashboard.title}.json", type: 'application/json'
    else
      redirect_to @analytics_dashboard, alert: 'Unsupported export format'
    end
  end
  
  # Analytics insights endpoint
  def insights
    insights_data = {
      performance_summary: generate_performance_insights,
      trend_analysis: generate_trend_insights,
      recommendations: generate_recommendations,
      alerts: generate_alerts
    }
    
    respond_to do |format|
      format.json { render json: insights_data }
      format.html { @insights = insights_data }
    end
  end
  
  private
  
  def set_analytics_dashboard
    @analytics_dashboard = AnalyticsDashboard.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to analytics_dashboards_url, alert: 'Dashboard not found.'
  end
  
  def authorize_dashboard_access
    unless @analytics_dashboard.user == current_user || 
           current_user.role == 'admin' ||
           (@analytics_dashboard.department && current_user.department == @analytics_dashboard.department)
      redirect_to analytics_dashboards_url, alert: 'Access denied.'
    end
  end
  
  def dashboard_params
    params.require(:analytics_dashboard).permit(
      :title, :dashboard_type, :active, :department_id,
      layout_config: {}, filter_config: {}, permissions_config: {}
    )
  end
  
  def get_available_dashboard_types
    types = []
    types << 'student' if current_user.role == 'student'
    types << 'teacher' if current_user.role == 'teacher'
    types << 'admin' if current_user.role == 'admin'
    types << 'department' if current_user.department
    types << 'institutional' if current_user.role == 'admin'
    types
  end
  
  def get_default_dashboards_for_user
    case current_user.role
    when 'student'
      [
        {
          title: 'My Academic Performance',
          type: 'student',
          description: 'Track your grades, assignments, and attendance'
        }
      ]
    when 'teacher'
      [
        {
          title: 'Class Analytics',
          type: 'teacher',
          description: 'Monitor student performance and engagement'
        },
        {
          title: 'Teaching Dashboard',
          type: 'teacher',
          description: 'Manage assignments and track class progress'
        }
      ]
    when 'admin'
      [
        {
          title: 'Institutional Overview',
          type: 'admin',
          description: 'University-wide metrics and analytics'
        },
        {
          title: 'Department Comparison',
          type: 'department',
          description: 'Compare performance across departments'
        }
      ]
    else
      []
    end
  end
  
  def create_default_widgets(dashboard)
    layout = dashboard.layout_config
    return unless layout && layout['widgets']
    
    layout['widgets'].each do |widget_config|
      DashboardWidget.create_from_template(
        dashboard,
        widget_config['type'],
        widget_config['position']
      )
    end
  end
  
  def generate_dashboard_pdf(dashboard)
    # This would integrate with a PDF generation library like Prawn or wicked_pdf
    # For now, return a placeholder
    "PDF generation would be implemented here for dashboard: #{dashboard.title}"
  end
  
  def generate_dashboard_excel(dashboard)
    # This would integrate with an Excel generation library like axlsx
    # For now, return a placeholder
    "Excel generation would be implemented here for dashboard: #{dashboard.title}"
  end
  
  def generate_performance_insights
    case current_user.role
    when 'student'
      {
        grade_trend: calculate_student_grade_trend,
        improvement_areas: identify_improvement_areas,
        achievements: identify_achievements
      }
    when 'teacher'
      {
        class_performance: calculate_class_performance_insights,
        student_engagement: calculate_engagement_insights,
        assignment_effectiveness: calculate_assignment_effectiveness
      }
    when 'admin'
      {
        institutional_health: calculate_institutional_health,
        department_performance: calculate_department_performance,
        resource_utilization: calculate_resource_utilization
      }
    else
      {}
    end
  end
  
  def generate_trend_insights
    {
      performance_trends: analyze_performance_trends,
      attendance_patterns: analyze_attendance_patterns,
      engagement_trends: analyze_engagement_trends
    }
  end
  
  def generate_recommendations
    case current_user.role
    when 'student'
      generate_student_recommendations
    when 'teacher'
      generate_teacher_recommendations
    when 'admin'
      generate_admin_recommendations
    else
      []
    end
  end
  
  def generate_alerts
    alerts = []
    
    # Performance alerts
    if current_user.role == 'student'
      alerts += check_student_performance_alerts
    elsif current_user.role == 'teacher'
      alerts += check_teacher_alerts
    elsif current_user.role == 'admin'
      alerts += check_system_alerts
    end
    
    alerts
  end
  
  # Placeholder methods for insights generation
  # These would contain actual analytics logic
  
  def calculate_student_grade_trend
    # Analyze student's grade progression over time
    'improving' # placeholder
  end
  
  def identify_improvement_areas
    # Identify subjects or topics where student needs improvement
    ['Math', 'Programming'] # placeholder
  end
  
  def identify_achievements
    # Identify student achievements and milestones
    ['Honor Roll', 'Perfect Attendance'] # placeholder
  end
  
  def generate_student_recommendations
    [
      {
        type: 'study_schedule',
        title: 'Optimize Study Schedule',
        description: 'Based on your performance patterns, studying in the morning shows better results.'
      },
      {
        type: 'resource',
        title: 'Additional Resources',
        description: 'Consider reviewing supplementary materials for Programming fundamentals.'
      }
    ]
  end
  
  def generate_teacher_recommendations
    [
      {
        type: 'engagement',
        title: 'Increase Student Engagement',
        description: 'Consider adding more interactive elements to your lectures.'
      }
    ]
  end
  
  def generate_admin_recommendations
    [
      {
        type: 'resource_allocation',
        title: 'Resource Optimization',
        description: 'Consider reallocating resources to high-demand departments.'
      }
    ]
  end
  
  def check_student_performance_alerts
    alerts = []
    
    # Check for declining grades
    recent_grades = current_user.submissions.where(created_at: 30.days.ago..Time.current)
                                          .where.not(grade: nil)
                                          .order(:created_at)
                                          .limit(5)
                                          .pluck(:grade)
    
    if recent_grades.length >= 3 && recent_grades.last < recent_grades.first - 10
      alerts << {
        type: 'warning',
        title: 'Declining Performance',
        message: 'Your recent grades show a declining trend. Consider seeking additional support.'
      }
    end
    
    alerts
  end
  
  def check_teacher_alerts
    # Check for classes with low engagement, overdue grading, etc.
    []
  end
  
  def check_system_alerts
    # Check for system-wide issues, resource constraints, etc.
    []
  end
end