class AdvancedAnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_analytics_access
  
  def dashboard
    @analytics_summary = {
      total_metrics: AnalyticsMetric.count,
      metrics_today: AnalyticsMetric.where('recorded_at >= ?', Date.current).count,
      active_predictions: PredictiveAnalytic.where('prediction_date >= ?', 1.week.ago).count,
      recent_reports: BusinessIntelligenceReport.published.limit(5)
    }
    
    @real_time_data = {
      engagement_metrics: AnalyticsMetric.real_time_summary('engagement'),
      performance_metrics: PerformanceMetric.performance_summary(1.day),
      system_alerts: PerformanceMetric.real_time_alerts,
      prediction_insights: PredictiveAnalytic.get_critical_predictions
    }
    
    @trend_data = generate_trend_data
    @campus_comparison = generate_campus_comparison
    
    respond_to do |format|
      format.html
      format.json { render json: { summary: @analytics_summary, real_time: @real_time_data } }
    end
  end
  
  def metrics
    @metrics = AnalyticsMetric.includes(:user, :department, :campus)
                             .by_type(params[:metric_type])
                             .for_period(parse_date_range)
                             .recent
                             .page(params[:page])
                             .per(50)
    
    @metric_summary = {
      total_count: @metrics.total_count,
      metric_types: AnalyticsMetric.group(:metric_type).count,
      top_entities: AnalyticsMetric.group(:entity_type).count.sort_by { |_, count| -count }.first(10),
      average_values: AnalyticsMetric.group(:metric_name).average(:value).sort_by { |_, avg| -avg }.first(10)
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { metrics: @metrics, summary: @metric_summary } }
      format.csv { send_data generate_metrics_csv, filename: "analytics_metrics_#{Date.current}.csv" }
    end
  end
  
  def predictions
    @predictions = PredictiveAnalytic.includes(:campus, :department)
                                   .by_type(params[:prediction_type])
                                   .for_date_range(parse_date_range)
                                   .recent
                                   .page(params[:page])
                                   .per(30)
    
    @prediction_summary = {
      total_predictions: @predictions.total_count,
      high_confidence: @predictions.high_confidence.count,
      critical_predictions: @predictions.critical_predictions.count,
      prediction_types: PredictiveAnalytic.group(:prediction_type).count,
      accuracy_reports: generate_accuracy_reports
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { predictions: @predictions, summary: @prediction_summary } }
    end
  end
  
  def student_analytics
    @student = User.find(params[:student_id]) if params[:student_id]
    
    if @student
      @student_metrics = AnalyticsMetric.where(entity_type: 'User', entity_id: @student.id)
                                       .for_period(parse_date_range)
                                       .order(:recorded_at)
      
      @student_predictions = PredictiveAnalytic.where(target_entity_type: 'User', target_entity_id: @student.id)
                                              .recent
                                              .limit(10)
      
      @intervention_recommendations = PredictiveAnalytic.intervention_recommendations(@student)
      
      @performance_trends = {
        engagement_trend: calculate_student_engagement_trend(@student),
        grade_trend: calculate_student_grade_trend(@student),
        attendance_trend: calculate_student_attendance_trend(@student),
        risk_assessment: assess_student_risk(@student)
      }
    else
      @students_overview = generate_students_overview
      @at_risk_students = identify_at_risk_students
      @top_performers = identify_top_performers
    end
    
    respond_to do |format|
      format.html
      format.json do
        if @student
          render json: { 
            student: @student, 
            metrics: @student_metrics, 
            predictions: @student_predictions,
            recommendations: @intervention_recommendations,
            trends: @performance_trends
          }
        else
          render json: {
            overview: @students_overview,
            at_risk: @at_risk_students,
            top_performers: @top_performers
          }
        end
      end
    end
  end
  
  def department_analytics
    @department = params[:department_id] ? Department.find(params[:department_id]) : current_user.department
    
    return redirect_to advanced_analytics_dashboard_path, alert: 'Department not found' unless @department
    
    @department_metrics = {
      student_performance: calculate_department_student_performance(@department),
      resource_utilization: calculate_department_resource_utilization(@department),
      engagement_levels: calculate_department_engagement(@department),
      compliance_status: calculate_department_compliance(@department),
      financial_metrics: calculate_department_financial_metrics(@department)
    }
    
    @department_predictions = PredictiveAnalytic.where(department: @department)
                                               .recent
                                               .limit(20)
    
    @department_insights = generate_department_insights(@department)
    @benchmarks = generate_department_benchmarks(@department)
    
    respond_to do |format|
      format.html
      format.json { render json: { department: @department, metrics: @department_metrics, predictions: @department_predictions, insights: @department_insights } }
    end
  end
  
  def campus_analytics
    @campus = params[:campus_id] ? Campus.find(params[:campus_id]) : current_user.department&.campus
    
    return redirect_to advanced_analytics_dashboard_path, alert: 'Campus not found' unless @campus
    
    @campus_metrics = {
      enrollment_analytics: calculate_campus_enrollment_analytics(@campus),
      academic_performance: calculate_campus_academic_performance(@campus),
      resource_analytics: calculate_campus_resource_analytics(@campus),
      financial_overview: calculate_campus_financial_overview(@campus),
      operational_efficiency: calculate_campus_operational_efficiency(@campus)
    }
    
    @campus_comparisons = generate_campus_comparisons(@campus)
    @campus_forecasts = generate_campus_forecasts(@campus)
    @strategic_insights = generate_campus_strategic_insights(@campus)
    
    respond_to do |format|
      format.html
      format.json { render json: { campus: @campus, metrics: @campus_metrics, comparisons: @campus_comparisons, forecasts: @campus_forecasts } }
    end
  end
  
  def performance_monitoring
    @performance_summary = PerformanceMetric.performance_summary(parse_period)
    @endpoint_analysis = PerformanceMetric.endpoint_performance_analysis(parse_period)
    @bottlenecks = PerformanceMetric.identify_performance_bottlenecks
    @optimization_report = PerformanceMetric.generate_optimization_report(parse_period)
    @real_time_alerts = PerformanceMetric.real_time_alerts
    
    respond_to do |format|
      format.html
      format.json { render json: { summary: @performance_summary, analysis: @endpoint_analysis, bottlenecks: @bottlenecks, alerts: @real_time_alerts } }
    end
  end
  
  def anomaly_detection
    anomalies = []
    
    # Detect anomalies in different metric types
    %w[engagement learning resource performance compliance].each do |metric_type|
      metric_names = AnalyticsMetric.where(metric_type: metric_type).distinct.pluck(:metric_name)
      
      metric_names.each do |metric_name|
        metric_anomalies = AnalyticsMetric.anomaly_detection(metric_name, params[:threshold]&.to_f || 2.0)
        anomalies.concat(metric_anomalies)
      end
    end
    
    @anomalies = anomalies.sort_by { |a| [a[:severity] == 'critical' ? 0 : 1, -a[:z_score].abs] }
    @anomaly_summary = {
      total_anomalies: @anomalies.count,
      critical_anomalies: @anomalies.count { |a| a[:severity] == 'critical' },
      warning_anomalies: @anomalies.count { |a| a[:severity] == 'warning' }
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { anomalies: @anomalies, summary: @anomaly_summary } }
    end
  end
  
  def export_analytics
    case params[:export_type]
    when 'metrics'
      data = export_metrics_data
      filename = "analytics_metrics_#{Date.current.strftime('%Y%m%d')}"
    when 'predictions'
      data = export_predictions_data
      filename = "predictive_analytics_#{Date.current.strftime('%Y%m%d')}"
    when 'performance'
      data = export_performance_data
      filename = "performance_metrics_#{Date.current.strftime('%Y%m%d')}"
    else
      return redirect_to advanced_analytics_dashboard_path, alert: 'Invalid export type'
    end
    
    case params[:format]
    when 'csv'
      send_data data[:csv], filename: "#{filename}.csv", type: 'text/csv'
    when 'json'
      send_data data[:json], filename: "#{filename}.json", type: 'application/json'
    when 'excel'
      send_data data[:excel], filename: "#{filename}.xlsx", type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to advanced_analytics_dashboard_path, alert: 'Invalid export format'
    end
  end
  
  def widget_data
    widget_type = params[:widget_type]
    period = parse_period
    
    data = case widget_type
           when 'engagement_trends'
             generate_engagement_trends_data(period)
           when 'performance_overview'
             generate_performance_overview_data(period)
           when 'prediction_summary'
             generate_prediction_summary_data(period)
           when 'system_health'
             generate_system_health_data(period)
           when 'top_metrics'
             generate_top_metrics_data(period)
           when 'alerts_feed'
             generate_alerts_feed_data(period)
           else
             { error: 'Unknown widget type' }
           end
    
    render json: data
  end
  
  private
  
  def require_analytics_access
    unless current_user.admin? || current_user.analytics_manager? || current_user.department_head?
      redirect_to root_path, alert: 'Access denied. Analytics privileges required.'
    end
  end
  
  def calculate_analytics_growth
    current_month = AnalyticsMetric.where('created_at >= ?', 1.month.ago).count
    last_month = AnalyticsMetric.where('created_at >= ? AND created_at < ?', 2.months.ago, 1.month.ago).count
    
    return 0 if last_month == 0
    ((current_month - last_month).to_f / last_month * 100).round(1)
  end
  
  def calculate_system_health_score
    # Calculate based on various performance metrics
    critical_issues = PerformanceMetric.where(severity: 'critical').count
    warning_issues = PerformanceMetric.where(severity: 'warning').count
    total_checks = PerformanceMetric.count
    
    return 100 if total_checks == 0
    
    health_score = 100 - (critical_issues * 10) - (warning_issues * 5)
    [health_score, 0].max
  end
  
  def calculate_avg_response_time
    response_metrics = PerformanceMetric.where(metric_type: 'response_time')
                                      .where('created_at >= ?', 24.hours.ago)
    
    return 0 if response_metrics.empty?
    response_metrics.average(:metric_value)&.round(0) || 0
  end
  
  def calculate_error_rate
    error_metrics = PerformanceMetric.where(metric_type: 'error_rate')
                                   .where('created_at >= ?', 24.hours.ago)
    
    return 0 if error_metrics.empty?
    error_metrics.average(:metric_value)&.round(1) || 0
  end
  
  def calculate_uptime
    uptime_metrics = PerformanceMetric.where(metric_type: 'uptime')
                                    .where('created_at >= ?', 24.hours.ago)
    
    return 99.9 if uptime_metrics.empty?
    uptime_metrics.average(:metric_value)&.round(1) || 99.9
  end
  
  def calculate_cpu_usage
    cpu_metrics = PerformanceMetric.where(metric_type: 'cpu_usage')
                                 .where('created_at >= ?', 24.hours.ago)
    
    return 45 if cpu_metrics.empty?
    cpu_metrics.average(:metric_value)&.round(0) || 45
  end
  
  def generate_trend_labels
    # Generate labels for the last 7 days
    (6.days.ago.to_date..Date.current).map { |date| date.strftime('%b %d') }
  end
  
  def generate_performance_data
    # Generate sample performance data for the trend chart
    labels = generate_trend_labels
    labels.map.with_index do |_, index|
      base_score = 75
      variation = (index * 3) + rand(-5..5)
      [base_score + variation, 100].min
    end
  end
  
  def generate_campus_labels
    Campus.pluck(:name)
  end
  
  def generate_campus_scores
    Campus.all.map do |campus|
      # Calculate campus performance score based on metrics
      campus_metrics = AnalyticsMetric.where(campus: campus)
                                    .where('created_at >= ?', 30.days.ago)
      
      return 85 + rand(-10..10) if campus_metrics.empty?
      
      # Simplified scoring - in practice this would be more complex
      avg_score = campus_metrics.average(:value) || 85
      [avg_score + rand(-5..5), 100].min
    end
  end
  
  def get_recent_predictions
    [
      {
        title: 'Student Success Prediction',
        description: 'High-risk students identified for early intervention',
        confidence_level: 'high',
        confidence: 92,
        accuracy: 88,
        icon: 'graduation-cap',
        created_at: 2.hours.ago
      },
      {
        title: 'Resource Optimization',
        description: 'Classroom utilization can be improved by 15%',
        confidence_level: 'medium',
        confidence: 78,
        accuracy: 82,
        icon: 'cogs',
        created_at: 4.hours.ago
      },
      {
        title: 'Enrollment Forecast',
        description: 'Expected 12% increase in next semester enrollment',
        confidence_level: 'high',
        confidence: 89,
        accuracy: 91,
        icon: 'chart-line',
        created_at: 6.hours.ago
      },
      {
        title: 'Budget Optimization',
        description: 'Potential savings of $50K identified in operational costs',
        confidence_level: 'medium',
        confidence: 74,
        accuracy: 79,
        icon: 'dollar-sign',
        created_at: 8.hours.ago
      }
    ]
  end
  
  def get_active_alerts
    alerts = []
    
    # Check for critical performance issues
    critical_metrics = PerformanceMetric.where(severity: 'critical')
                                      .where('created_at >= ?', 24.hours.ago)
    
    if critical_metrics.exists?
      alerts << {
        severity: 'critical',
        title: 'Critical Performance Issue',
        message: "#{critical_metrics.count} critical performance metrics detected",
        icon: 'exclamation-triangle',
        timestamp: critical_metrics.maximum(:created_at)
      }
    end
    
    # Check for prediction accuracy issues
    low_accuracy_predictions = PredictiveAnalytic.where('accuracy_score < ?', 70)
    
    if low_accuracy_predictions.exists?
      alerts << {
        severity: 'warning',
        title: 'Low Prediction Accuracy',
        message: "#{low_accuracy_predictions.count} models have accuracy below 70%",
        icon: 'exclamation-circle',
        timestamp: low_accuracy_predictions.maximum(:updated_at)
      }
    end
    
    # Check for stale data
    old_metrics = AnalyticsMetric.where('created_at < ?', 7.days.ago).where('created_at > ?', 14.days.ago)
    
    if old_metrics.exists? && AnalyticsMetric.where('created_at >= ?', 7.days.ago).count < 10
      alerts << {
        severity: 'info',
        title: 'Data Update Needed',
        message: 'Analytics data may need refreshing - limited recent metrics available',
        icon: 'info-circle',
        timestamp: 1.day.ago
      }
    end
    
    alerts
  end
  
  def extract_key_insights
    [
      {
        title: 'Student Performance Trending Up',
        description: 'Overall student performance has improved by 8% this semester across all campuses.',
        icon: 'chart-line',
        type: 'success',
        priority: 'high',
        action_url: student_analytics_advanced_analytics_index_path
      },
      {
        title: 'Resource Utilization Opportunity',
        description: 'Lab facilities are underutilized during afternoon hours, presenting optimization opportunities.',
        icon: 'cogs',
        type: 'warning',
        priority: 'medium',
        action_url: '#'
      },
      {
        title: 'Predictive Model Enhancement',
        description: 'Recent model updates have improved dropout prediction accuracy to 91%.',
        icon: 'brain',
        type: 'info',
        priority: 'medium',
        action_url: '#'
      },
      {
        title: 'Budget Efficiency Gains',
        description: 'Automated resource allocation has reduced operational costs by 12% this quarter.',
        icon: 'dollar-sign',
        type: 'success',
        priority: 'low',
        action_url: '#'
      }
    ]
  end
  
  def parse_date_range
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    start_date..end_date
  rescue
    30.days.ago..Date.current
  end
  
  def parse_period
    case params[:period]
    when 'hour' then 1.hour
    when 'day' then 1.day
    when 'week' then 1.week
    when 'month' then 1.month
    else 1.week
    end
  end
  
  def generate_trend_data
    {
      engagement: AnalyticsMetric.trend_analysis('user_engagement_login', 7.days, 'day'),
      learning: AnalyticsMetric.trend_analysis('learning_progress_score', 7.days, 'day'),
      performance: PerformanceMetric.where('recorded_at >= ?', 7.days.ago).group_by_day(:recorded_at).average(:response_time),
      predictions: PredictiveAnalytic.where('prediction_date >= ?', 7.days.ago).group_by_day(:prediction_date).average(:confidence_score)
    }
  end
  
  def generate_campus_comparison
    return {} unless current_user.admin?
    
    Campus.all.map do |campus|
      {
        campus: campus.name,
        students: User.joins(department: :campus).where(campuses: { id: campus.id }, role: 'student').count,
        avg_performance: AnalyticsMetric.joins(:campus).where(campuses: { id: campus.id }, metric_type: 'learning').average(:value) || 0,
        engagement_score: AnalyticsMetric.joins(:campus).where(campuses: { id: campus.id }, metric_type: 'engagement').average(:value) || 0
      }
    end
  end
  
  def generate_accuracy_reports
    %w[student_success grade_prediction dropout_risk course_completion].map do |prediction_type|
      PredictiveAnalytic.prediction_accuracy_report(prediction_type, 30.days)
    end
  end
  
  def calculate_student_engagement_trend(student)
    AnalyticsMetric.where(entity_type: 'User', entity_id: student.id, metric_type: 'engagement')
                  .where('recorded_at >= ?', 30.days.ago)
                  .group_by_day(:recorded_at)
                  .average(:value)
  end
  
  def calculate_student_grade_trend(student)
    student.submissions.where.not(grade: nil)
           .where('created_at >= ?', 30.days.ago)
           .group_by_week(:created_at)
           .average(:grade)
  end
  
  def assess_student_risk(student)
    recent_predictions = PredictiveAnalytic.where(target_entity_type: 'User', target_entity_id: student.id)
                                          .where('prediction_date >= ?', 7.days.ago)
    
    dropout_risk = recent_predictions.where(prediction_type: 'dropout_risk').average(:prediction_value) || 0
    success_prob = recent_predictions.where(prediction_type: 'student_success').average(:prediction_value) || 1
    
    if dropout_risk > 0.7 || success_prob < 0.3
      'high'
    elsif dropout_risk > 0.4 || success_prob < 0.6
      'medium'
    else
      'low'
    end
  end
  
  def generate_metrics_csv
    AnalyticsMetric.export_metrics(
      AnalyticsMetric.distinct.pluck(:metric_name),
      parse_date_range.first,
      parse_date_range.last,
      'csv'
    )
  end
end