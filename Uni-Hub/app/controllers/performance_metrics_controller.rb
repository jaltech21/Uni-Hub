class PerformanceMetricsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_performance_access
  before_action :set_performance_metric, only: [:show, :edit, :update, :destroy, :analyze]
  
  def index
    @metrics = PerformanceMetric.includes_associations
                               .by_metric_type(params[:metric_type])
                               .by_severity(params[:severity])
                               .by_date_range(params[:start_date], params[:end_date])
                               .recent
                               .page(params[:page])
                               .per(25)
    
    @metrics_summary = {
      total_metrics: PerformanceMetric.count,
      critical_issues: PerformanceMetric.where(severity: 'critical').count,
      warnings: PerformanceMetric.where(severity: 'warning').count,
      metrics_today: PerformanceMetric.where('created_at >= ?', Date.current.beginning_of_day).count
    }
    
    @metric_types = PerformanceMetric.distinct.pluck(:metric_type)
    @severity_levels = PerformanceMetric.distinct.pluck(:severity)
    
    respond_to do |format|
      format.html
      format.json { render json: { metrics: @metrics, summary: @metrics_summary } }
    end
  end
  
  def show
    @performance_data = @performance_metric.performance_data || {}
    @optimization_recommendations = @performance_metric.optimization_recommendations || []
    @related_metrics = find_related_metrics(@performance_metric)
    @trend_analysis = @performance_metric.analyze_trends
    
    respond_to do |format|
      format.html
      format.json { 
        render json: @performance_metric.as_json(
          methods: [:optimization_suggestions, :performance_score, :trend_analysis]
        )
      }
    end
  end
  
  def new
    @performance_metric = PerformanceMetric.new
    @metric_templates = get_performance_templates
  end
  
  def create
    @performance_metric = PerformanceMetric.new(performance_metric_params)
    
    if @performance_metric.save
      # Trigger analysis and optimization suggestions
      @performance_metric.analyze_performance!
      @performance_metric.generate_optimization_recommendations!
      
      redirect_to @performance_metric, notice: 'Performance metric created and analysis initiated.'
    else
      @metric_templates = get_performance_templates
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @performance_metric.update(performance_metric_params)
      # Re-analyze if performance data changed
      @performance_metric.analyze_performance! if performance_metric_params[:performance_data].present?
      redirect_to @performance_metric, notice: 'Performance metric updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @performance_metric.destroy
    redirect_to performance_metrics_url, notice: 'Performance metric was successfully deleted.'
  end
  
  def analyze
    begin
      analysis_results = @performance_metric.deep_performance_analysis
      optimization_suggestions = @performance_metric.generate_advanced_optimizations
      
      @performance_metric.update!(
        analysis_results: analysis_results,
        optimization_recommendations: optimization_suggestions,
        last_analyzed_at: Time.current
      )
      
      redirect_to @performance_metric, notice: 'Deep performance analysis completed successfully.'
    rescue => e
      redirect_to @performance_metric, alert: "Analysis failed: #{e.message}"
    end
  end
  
  def dashboard
    @dashboard_metrics = {
      total_metrics: PerformanceMetric.count,
      critical_alerts: PerformanceMetric.where(severity: 'critical').count,
      active_optimizations: count_active_optimizations,
      average_performance_score: calculate_average_performance_score
    }
    
    @performance_trends = {
      response_time_trends: calculate_response_time_trends,
      resource_utilization_trends: calculate_resource_utilization_trends,
      error_rate_trends: calculate_error_rate_trends,
      throughput_trends: calculate_throughput_trends
    }
    
    @system_health = {
      overall_health_score: calculate_overall_health_score,
      component_health: calculate_component_health,
      bottleneck_analysis: identify_system_bottlenecks,
      capacity_utilization: calculate_capacity_utilization
    }
    
    @optimization_insights = {
      top_optimization_opportunities: identify_top_optimizations,
      potential_savings: calculate_potential_savings,
      implementation_priorities: prioritize_optimizations,
      success_metrics: track_optimization_success
    }
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          metrics: @dashboard_metrics, 
          trends: @performance_trends, 
          health: @system_health,
          optimizations: @optimization_insights
        } 
      }
    end
  end
  
  def real_time_monitoring
    @real_time_data = {
      current_response_times: get_current_response_times,
      active_connections: get_active_connections,
      resource_usage: get_current_resource_usage,
      error_rates: get_current_error_rates,
      throughput_metrics: get_current_throughput
    }
    
    @alerts = {
      critical_alerts: get_critical_alerts,
      warning_alerts: get_warning_alerts,
      performance_anomalies: detect_performance_anomalies,
      threshold_breaches: detect_threshold_breaches
    }
    
    @system_status = {
      overall_status: determine_overall_system_status,
      component_statuses: get_component_statuses,
      service_availability: calculate_service_availability,
      performance_grade: calculate_performance_grade
    }
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          data: @real_time_data, 
          alerts: @alerts, 
          status: @system_status,
          timestamp: Time.current
        } 
      }
    end
  end
  
  def optimization_recommendations
    @optimization_categories = {
      database_optimizations: get_database_optimizations,
      application_optimizations: get_application_optimizations,
      infrastructure_optimizations: get_infrastructure_optimizations,
      cache_optimizations: get_cache_optimizations,
      query_optimizations: get_query_optimizations
    }
    
    @implementation_plan = {
      high_priority: get_high_priority_optimizations,
      medium_priority: get_medium_priority_optimizations,
      low_priority: get_low_priority_optimizations,
      quick_wins: identify_quick_win_optimizations
    }
    
    @impact_analysis = {
      performance_impact: calculate_performance_impact,
      cost_savings: calculate_cost_savings,
      implementation_effort: calculate_implementation_effort,
      risk_assessment: assess_optimization_risks
    }
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          categories: @optimization_categories,
          plan: @implementation_plan,
          impact: @impact_analysis
        }
      }
    end
  end
  
  def capacity_planning
    @capacity_analysis = {
      current_capacity: analyze_current_capacity,
      projected_growth: project_capacity_growth,
      bottleneck_forecast: forecast_bottlenecks,
      scaling_recommendations: generate_scaling_recommendations
    }
    
    @resource_projections = {
      cpu_projections: project_cpu_needs,
      memory_projections: project_memory_needs,
      storage_projections: project_storage_needs,
      network_projections: project_network_needs
    }
    
    @cost_analysis = {
      current_costs: calculate_current_infrastructure_costs,
      projected_costs: calculate_projected_costs,
      optimization_savings: calculate_optimization_cost_savings,
      roi_analysis: perform_capacity_roi_analysis
    }
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          capacity: @capacity_analysis,
          projections: @resource_projections,
          costs: @cost_analysis
        }
      }
    end
  end
  
  def historical_analysis
    date_range = parse_date_range(params[:start_date], params[:end_date])
    
    @historical_data = {
      performance_history: get_performance_history(date_range),
      trend_analysis: analyze_historical_trends(date_range),
      pattern_recognition: identify_performance_patterns(date_range),
      seasonal_analysis: analyze_seasonal_patterns(date_range)
    }
    
    @comparison_analysis = {
      period_comparisons: compare_performance_periods(date_range),
      benchmark_comparisons: compare_against_benchmarks(date_range),
      improvement_tracking: track_performance_improvements(date_range),
      regression_analysis: identify_performance_regressions(date_range)
    }
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          historical: @historical_data,
          comparisons: @comparison_analysis,
          date_range: date_range
        }
      }
    end
  end
  
  def export_metrics
    date_range = parse_date_range(params[:start_date], params[:end_date])
    metric_types = params[:metric_types]&.split(',') || []
    
    case params[:format]
    when 'csv'
      csv_data = generate_metrics_csv(date_range, metric_types)
      send_data csv_data, 
                filename: "performance_metrics_#{Date.current.strftime('%Y%m%d')}.csv",
                type: 'text/csv'
      
    when 'json'
      json_data = generate_metrics_json(date_range, metric_types)
      send_data json_data,
                filename: "performance_metrics_#{Date.current.strftime('%Y%m%d')}.json",
                type: 'application/json'
      
    when 'excel'
      excel_file = generate_metrics_excel(date_range, metric_types)
      send_file excel_file,
                filename: "performance_metrics_#{Date.current.strftime('%Y%m%d')}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      
    else
      redirect_to performance_metrics_path, alert: 'Invalid export format'
    end
  end
  
  def bulk_analysis
    metric_ids = params[:metric_ids] || []
    analysis_type = params[:analysis_type] || 'standard'
    
    if metric_ids.empty?
      return redirect_to performance_metrics_path, alert: 'No metrics selected for analysis'
    end
    
    begin
      metrics = PerformanceMetric.where(id: metric_ids)
      
      case analysis_type
      when 'correlation'
        results = perform_correlation_analysis(metrics)
      when 'trend'
        results = perform_trend_analysis(metrics)
      when 'anomaly'
        results = perform_anomaly_detection(metrics)
      when 'optimization'
        results = perform_bulk_optimization_analysis(metrics)
      else
        results = perform_standard_bulk_analysis(metrics)
      end
      
      render json: {
        success: true,
        results: results,
        analysis_type: analysis_type,
        metrics_analyzed: metrics.count
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_performance_metric
    @performance_metric = PerformanceMetric.find(params[:id])
  end
  
  def performance_metric_params
    params.require(:performance_metric).permit(
      :metric_name, :metric_type, :metric_value, :threshold_value,
      :severity, :description,
      performance_data: {}, optimization_recommendations: []
    )
  end
  
  def require_performance_access
    unless current_user.admin? || current_user.system_administrator? || current_user.analytics_manager?
      redirect_to root_path, alert: 'Access denied. Performance monitoring privileges required.'
    end
  end
  
  def get_performance_templates
    [
      {
        name: 'Response Time Monitor',
        type: 'response_time',
        description: 'Monitor application response times and identify slow endpoints',
        threshold: 500, # milliseconds
        severity: 'warning'
      },
      {
        name: 'Memory Usage Monitor',
        type: 'memory_usage',
        description: 'Track memory consumption and detect memory leaks',
        threshold: 80, # percentage
        severity: 'critical'
      },
      {
        name: 'CPU Utilization Monitor',
        type: 'cpu_usage',
        description: 'Monitor CPU usage and identify processing bottlenecks',
        threshold: 75, # percentage
        severity: 'warning'
      },
      {
        name: 'Database Query Performance',
        type: 'query_performance',
        description: 'Monitor database query execution times and optimization opportunities',
        threshold: 1000, # milliseconds
        severity: 'warning'
      },
      {
        name: 'Error Rate Monitor',
        type: 'error_rate',
        description: 'Track application error rates and system stability',
        threshold: 5, # percentage
        severity: 'critical'
      }
    ]
  end
  
  def find_related_metrics(metric)
    PerformanceMetric.where(metric_type: metric.metric_type)
                    .where.not(id: metric.id)
                    .order(created_at: :desc)
                    .limit(5)
  end
  
  def count_active_optimizations
    PerformanceMetric.where.not(optimization_recommendations: nil)
                    .where('optimization_recommendations != ?', '[]')
                    .count
  end
  
  def calculate_average_performance_score
    scores = PerformanceMetric.where.not(performance_data: nil)
                             .pluck(:performance_data)
                             .map { |data| data['performance_score'] }
                             .compact
    
    return 0 if scores.empty?
    (scores.sum.to_f / scores.count).round(2)
  end
  
  def calculate_overall_health_score
    # Simplified health score calculation
    # In practice, this would be more sophisticated
    critical_count = PerformanceMetric.where(severity: 'critical').count
    warning_count = PerformanceMetric.where(severity: 'warning').count
    total_count = PerformanceMetric.count
    
    return 100 if total_count == 0
    
    health_score = 100 - (critical_count * 10) - (warning_count * 5)
    [health_score, 0].max
  end
  
  def parse_date_range(start_date, end_date)
    {
      start: start_date.present? ? Date.parse(start_date) : 30.days.ago.to_date,
      end: end_date.present? ? Date.parse(end_date) : Date.current
    }
  rescue Date::Error
    {
      start: 30.days.ago.to_date,
      end: Date.current
    }
  end
  
  def generate_metrics_csv(date_range, metric_types)
    require 'csv'
    
    metrics = PerformanceMetric.where(created_at: date_range[:start]..date_range[:end])
    metrics = metrics.where(metric_type: metric_types) if metric_types.any?
    
    CSV.generate(headers: true) do |csv|
      csv << ['Timestamp', 'Metric Name', 'Type', 'Value', 'Threshold', 'Severity', 'Description']
      
      metrics.each do |metric|
        csv << [
          metric.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          metric.metric_name,
          metric.metric_type,
          metric.metric_value,
          metric.threshold_value,
          metric.severity,
          metric.description
        ]
      end
    end
  end
end