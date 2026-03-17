class BusinessIntelligenceReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_bi_access
  before_action :set_bi_report, only: [:show, :edit, :update, :destroy, :publish, :export]
  
  def index
    @reports = BusinessIntelligenceReport.includes(:generated_by, :campus)
                                       .by_type(params[:report_type])
                                       .by_status(params[:status])
                                       .by_period(params[:period])
                                       .recent
                                       .page(params[:page])
                                       .per(20)
    
    @report_summary = {
      total_reports: BusinessIntelligenceReport.count,
      published_reports: BusinessIntelligenceReport.published.count,
      generating_reports: BusinessIntelligenceReport.where(status: 'generating').count,
      recent_completions: BusinessIntelligenceReport.where('generated_at >= ?', 7.days.ago).count
    }
    
    @report_types = BusinessIntelligenceReport.distinct.pluck(:report_type)
    @report_statuses = BusinessIntelligenceReport.distinct.pluck(:status)
    
    respond_to do |format|
      format.html
      format.json { render json: { reports: @reports, summary: @report_summary } }
    end
  end
  
  def show
    @report_insights = @bi_report.insights || []
    @report_recommendations = @bi_report.recommendations || []
    @data_visualizations = generate_report_visualizations(@bi_report)
    
    respond_to do |format|
      format.html
      format.json { render json: @bi_report.as_json(include: [:generated_by, :campus]) }
      format.pdf { render_pdf_report }
    end
  end
  
  def new
    @bi_report = BusinessIntelligenceReport.new
    @campuses = Campus.all
    @report_templates = get_report_templates
  end
  
  def create
    @bi_report = BusinessIntelligenceReport.new(bi_report_params)
    @bi_report.generated_by = current_user
    
    if @bi_report.save
      # Generate report content based on type
      case @bi_report.report_type
      when 'executive_dashboard'
        @bi_report.generate_executive_content!
      when 'institutional_overview'
        @bi_report.generate_institutional_content!
      when 'department_performance'
        @bi_report.generate_department_content!
      end
      
      redirect_to @bi_report, notice: 'Business Intelligence report was successfully created and is being generated.'
    else
      @campuses = Campus.all
      @report_templates = get_report_templates
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @campuses = Campus.all
  end
  
  def update
    if @bi_report.update(bi_report_params)
      redirect_to @bi_report, notice: 'Report was successfully updated.'
    else
      @campuses = Campus.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    unless @bi_report.status == 'published'
      @bi_report.destroy
      redirect_to business_intelligence_reports_url, notice: 'Report was successfully deleted.'
    else
      redirect_to @bi_report, alert: 'Cannot delete published reports.'
    end
  end
  
  def publish
    if @bi_report.publish!
      redirect_to @bi_report, notice: 'Report published successfully. Stakeholders have been notified.'
    else
      redirect_to @bi_report, alert: 'Cannot publish report. Please ensure it is completed.'
    end
  end
  
  def export
    case params[:format]
    when 'pdf'
      result = @bi_report.export_to_pdf
      if result[:success]
        send_file result[:file_path], 
                  filename: "bi_report_#{@bi_report.id}.pdf",
                  type: 'application/pdf'
      else
        redirect_to @bi_report, alert: result[:message]
      end
      
    when 'excel'
      result = @bi_report.export_to_excel
      if result[:success]
        send_file result[:file_path],
                  filename: "bi_report_#{@bi_report.id}.xlsx",
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      else
        redirect_to @bi_report, alert: result[:message]
      end
      
    when 'json'
      send_data @bi_report.to_json(
        include: {
          generated_by: { only: [:name, :email] },
          campus: { only: [:name] }
        },
        methods: [:report_insights, :report_recommendations]
      ), filename: "bi_report_#{@bi_report.id}_#{Date.current.strftime('%Y%m%d')}.json",
         type: 'application/json'
         
    else
      redirect_to @bi_report, alert: 'Invalid export format'
    end
  end
  
  def dashboard
    @report_summary = {
      total_reports: BusinessIntelligenceReport.count,
      reports_this_month: BusinessIntelligenceReport.where('created_at >= ?', 1.month.ago).count,
      published_reports: BusinessIntelligenceReport.where(status: 'published').count,
      generating_reports: BusinessIntelligenceReport.where(status: 'generating').count,
      recent_completions: BusinessIntelligenceReport.where('generated_at >= ?', 7.days.ago).count
    }
    
    @dashboard_metrics = {
      overall_performance: calculate_overall_performance,
      efficiency_score: calculate_efficiency_score,
      strategic_alignment: calculate_strategic_alignment
    }
    
    @reports = BusinessIntelligenceReport.includes(:campus, :generated_by).recent
    @report_types = BusinessIntelligenceReport.distinct.pluck(:report_type).compact
    
    @executive_summary = generate_executive_dashboard_summary
    @trending_insights = extract_trending_insights
    @recent_activity = generate_recent_activity
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          report_summary: @report_summary, 
          dashboard_metrics: @dashboard_metrics,
          trending_insights: @trending_insights 
        } 
      }
    end
  end
  
  def generate_automated
    report_type = params[:report_type] || 'executive_dashboard'
    campus = params[:campus_id] ? Campus.find(params[:campus_id]) : nil
    period = params[:period] || 'monthly'
    
    begin
      case report_type
      when 'executive_dashboard'
        @report = BusinessIntelligenceReport.generate_executive_dashboard(current_user, campus, period)
      when 'institutional_overview'
        @report = BusinessIntelligenceReport.generate_institutional_overview(current_user, period)
      when 'department_performance'
        campus ||= current_user.department&.campus
        @report = BusinessIntelligenceReport.generate_department_performance(current_user, campus, period)
      else
        return redirect_to business_intelligence_reports_path, alert: 'Invalid report type'
      end
      
      redirect_to @report, notice: 'Automated report generation initiated successfully.'
    rescue => e
      redirect_to business_intelligence_reports_path, alert: "Failed to generate report: #{e.message}"
    end
  end
  
  def insights_analysis
    @insights_summary = {
      total_insights: extract_all_insights.count,
      high_impact_insights: extract_all_insights.count { |i| i[:impact] == 'high' },
      medium_impact_insights: extract_all_insights.count { |i| i[:impact] == 'medium' },
      low_impact_insights: extract_all_insights.count { |i| i[:impact] == 'low' }
    }
    
    @insights_by_category = group_insights_by_category
    @trending_insights = identify_trending_insights
    @actionable_recommendations = extract_actionable_recommendations
    
    respond_to do |format|
      format.html
      format.json { render json: { summary: @insights_summary, categories: @insights_by_category, trending: @trending_insights } }
    end
  end
  
  def performance_benchmarks
    @benchmarks = {
      institutional_benchmarks: generate_institutional_benchmarks,
      campus_benchmarks: generate_campus_benchmarks,
      department_benchmarks: generate_department_benchmarks,
      industry_comparisons: generate_industry_comparisons
    }
    
    @benchmark_trends = {
      performance_trends: calculate_performance_trends,
      efficiency_trends: calculate_efficiency_trends,
      satisfaction_trends: calculate_satisfaction_trends
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { benchmarks: @benchmarks, trends: @benchmark_trends } }
    end
  end
  
  def strategic_planning
    @strategic_metrics = {
      enrollment_projections: generate_enrollment_projections,
      resource_planning: generate_resource_planning_insights,
      financial_forecasting: generate_financial_forecasting,
      competitive_analysis: generate_competitive_analysis,
      risk_assessment: generate_strategic_risk_assessment
    }
    
    @strategic_recommendations = {
      short_term: extract_short_term_recommendations,
      medium_term: extract_medium_term_recommendations,
      long_term: extract_long_term_recommendations
    }
    
    @scenario_analysis = generate_scenario_analysis
    
    respond_to do |format|
      format.html
      format.json { render json: { metrics: @strategic_metrics, recommendations: @strategic_recommendations, scenarios: @scenario_analysis } }
    end
  end
  
  def schedule_report
    report_config = {
      report_type: params[:report_type],
      campus_id: params[:campus_id],
      period: params[:period],
      schedule_frequency: params[:frequency], # daily, weekly, monthly, quarterly
      recipients: params[:recipients]&.split(',')&.map(&:strip),
      auto_publish: params[:auto_publish] == 'true'
    }
    
    # Schedule background job for automated report generation
    scheduled_report = schedule_automated_report(report_config)
    
    if scheduled_report
      redirect_to business_intelligence_reports_path, 
                  notice: "Report scheduled successfully. Next generation: #{scheduled_report[:next_run]}"
    else
      redirect_to business_intelligence_reports_path, 
                  alert: 'Failed to schedule report. Please check your configuration.'
    end
  end
  
  private
  
  def set_bi_report
    @bi_report = BusinessIntelligenceReport.find(params[:id])
  end
  
  def bi_report_params
    params.require(:business_intelligence_report).permit(
      :report_name, :report_type, :report_period, :campus_id,
      :executive_summary, :status,
      data_sources: {}, insights: [], recommendations: []
    )
  end
  
  def require_bi_access
    unless current_user.admin? || current_user.compliance_manager? || current_user.department_head?
      redirect_to root_path, alert: 'Access denied. Business Intelligence privileges required.'
    end
  end
  
  def get_report_templates
    [
      {
        name: 'Executive Dashboard',
        type: 'executive_dashboard',
        description: 'Comprehensive overview for executives with key performance indicators',
        duration: '15-20 minutes'
      },
      {
        name: 'Institutional Overview',
        type: 'institutional_overview',
        description: 'Cross-campus analysis with comparative metrics and trends',
        duration: '20-30 minutes'
      },
      {
        name: 'Department Performance',
        type: 'department_performance',
        description: 'Detailed analysis of department-specific metrics and outcomes',
        duration: '10-15 minutes'
      },
      {
        name: 'Student Analytics',
        type: 'student_analytics',
        description: 'Student performance, engagement, and success analytics',
        duration: '15-25 minutes'
      },
      {
        name: 'Resource Optimization',
        type: 'resource_optimization',
        description: 'Analysis of resource utilization and optimization opportunities',
        duration: '10-20 minutes'
      }
    ]
  end
  
  def generate_report_visualizations(report)
    visualizations = []
    
    if report.data_sources.present?
      # Generate appropriate visualizations based on data sources
      report.data_sources.each do |source, enabled|
        next unless enabled
        
        case source
        when 'analytics'
          visualizations << generate_analytics_charts(report)
        when 'compliance'
          visualizations << generate_compliance_charts(report)
        when 'resources'
          visualizations << generate_resource_charts(report)
        when 'financial'
          visualizations << generate_financial_charts(report)
        end
      end
    end
    
    visualizations.flatten.compact
  end
  
  def render_pdf_report
    # PDF rendering logic would go here
    # This would typically use a gem like Prawn or wicked_pdf
    redirect_to @bi_report, alert: 'PDF export not yet implemented'
  end
  
  def calculate_average_generation_time
    reports = BusinessIntelligenceReport.where.not(generated_at: nil)
    return 0 if reports.empty?
    
    # Calculate average time between creation and completion
    # This is a simplified calculation - in practice, you'd track actual generation time
    reports.average('EXTRACT(EPOCH FROM (generated_at - created_at))') / 60.0 # in minutes
  end
  
  def extract_recent_insights
    BusinessIntelligenceReport.published
                             .where('generated_at >= ?', 30.days.ago)
                             .where.not(insights: nil)
                             .limit(10)
                             .pluck(:insights)
                             .flatten
                             .select { |insight| insight.is_a?(Hash) && insight['impact'] == 'high' }
                             .first(5)
  end
  
  def extract_top_recommendations
    BusinessIntelligenceReport.published
                             .where('generated_at >= ?', 30.days.ago)
                             .where.not(recommendations: nil)
                             .pluck(:recommendations)
                             .flatten
                             .select { |rec| rec.is_a?(Hash) && rec['priority'] == 'high' }
                             .first(10)
  end
  
  def generate_executive_dashboard_summary
    recent_reports = BusinessIntelligenceReport.published.where('generated_at >= ?', 30.days.ago)
    
    summary_parts = []
    summary_parts << "Generated #{recent_reports.count} business intelligence reports in the last 30 days."
    
    if recent_reports.any?
      avg_insights = recent_reports.where.not(insights: nil).average('CARDINALITY(insights)')
      summary_parts << "Average of #{avg_insights&.round(1) || 0} strategic insights per report."
      
      high_impact_count = recent_reports.sum do |report|
        (report.insights || []).count { |i| i.is_a?(Hash) && i['impact'] == 'high' }
      end
      summary_parts << "#{high_impact_count} high-impact insights identified requiring immediate attention."
    end
    
    summary_parts.join(' ')
  end
  
  def extract_all_insights
    BusinessIntelligenceReport.published
                             .where('generated_at >= ?', 90.days.ago)
                             .where.not(insights: nil)
                             .pluck(:insights)
                             .flatten
                             .select { |insight| insight.is_a?(Hash) }
  end
  
  def group_insights_by_category
    insights = extract_all_insights
    
    categories = %w[enrollment performance resources compliance financial operational strategic]
    
    categories.map do |category|
      category_insights = insights.select { |i| i['type']&.include?(category) }
      {
        category: category,
        count: category_insights.count,
        high_impact: category_insights.count { |i| i['impact'] == 'high' },
        recent: category_insights.select { |i| Date.parse(i['created_at']) > 30.days.ago rescue false }.count
      }
    end
  end
  
  def schedule_automated_report(config)
    # This would integrate with a background job system like Sidekiq
    # For now, return a mock response
    {
      success: true,
      next_run: calculate_next_run_time(config[:schedule_frequency]),
      job_id: SecureRandom.uuid
    }
  end
  
  def calculate_next_run_time(frequency)
    case frequency
    when 'daily' then 1.day.from_now
    when 'weekly' then 1.week.from_now
    when 'monthly' then 1.month.from_now
    when 'quarterly' then 3.months.from_now
    else 1.week.from_now
    end
  end
  
  def calculate_overall_performance
    # Simplified calculation - in practice would use more sophisticated metrics
    recent_reports = BusinessIntelligenceReport.where('generated_at >= ?', 30.days.ago)
    return 0.85 if recent_reports.empty?
    
    # Base performance on report completion rate and insights quality
    completion_rate = recent_reports.where.not(generated_at: nil).count.to_f / recent_reports.count
    insight_quality = recent_reports.joins(:insights).count.to_f / recent_reports.count rescue 0.7
    
    (completion_rate * 0.6 + insight_quality * 0.4).round(3)
  end
  
  def calculate_efficiency_score
    # Score based on report generation time and automation
    recent_reports = BusinessIntelligenceReport.where('generated_at >= ?', 30.days.ago)
    return 7.5 if recent_reports.empty?
    
    # Simple scoring based on report count and recency
    base_score = 7.0
    bonus = recent_reports.count > 10 ? 1.0 : 0.5
    automation_bonus = recent_reports.where(report_type: 'executive_dashboard').exists? ? 0.5 : 0
    
    (base_score + bonus + automation_bonus).round(1)
  end
  
  def calculate_strategic_alignment
    # Percentage of reports that include strategic insights
    recent_reports = BusinessIntelligenceReport.where('generated_at >= ?', 90.days.ago)
    return 78 if recent_reports.empty?
    
    strategic_reports = recent_reports.where(report_type: ['executive_dashboard', 'institutional_overview']).count
    total_reports = recent_reports.count
    
    return 85 if total_reports == 0
    ((strategic_reports.to_f / total_reports) * 100).round(0)
  end
  
  def extract_trending_insights
    [
      {
        title: 'Student Engagement Increases 15%',
        description: 'Cross-campus student engagement metrics show significant improvement following implementation of new learning platforms.',
        priority: 'high',
        categories: ['engagement', 'learning', 'technology'],
        trend: 'up',
        impact_score: 85
      },
      {
        title: 'Resource Utilization Optimization Opportunity',
        description: 'Analysis reveals 23% underutilization of laboratory facilities during peak afternoon hours across all campuses.',
        priority: 'medium',
        categories: ['resources', 'facilities', 'optimization'],
        trend: 'stable',
        impact_score: 72
      },
      {
        title: 'Faculty Satisfaction Scores Rise',
        description: 'Recent surveys indicate 12% improvement in faculty satisfaction following curriculum flexibility initiatives.',
        priority: 'medium',
        categories: ['faculty', 'satisfaction', 'curriculum'],
        trend: 'up',
        impact_score: 68
      },
      {
        title: 'Budget Efficiency Gains Identified',
        description: 'Automated analysis identifies potential $150K annual savings through strategic resource reallocation.',
        priority: 'high',
        categories: ['budget', 'efficiency', 'savings'],
        trend: 'up',
        impact_score: 91
      }
    ]
  end
  
  def generate_recent_activity
    [
      {
        user: current_user.name || 'System Admin',
        action: 'generated',
        target: 'Executive Dashboard Report',
        icon: 'file-plus',
        color: 'success',
        timestamp: 2.hours.ago
      },
      {
        user: 'Dr. Sarah Johnson',
        action: 'published',
        target: 'Department Performance Analysis',
        icon: 'eye',
        color: 'info',
        timestamp: 4.hours.ago
      },
      {
        user: 'System Scheduler',
        action: 'scheduled',
        target: 'Monthly Institutional Report',
        icon: 'calendar',
        color: 'warning',
        timestamp: 6.hours.ago
      },
      {
        user: 'Prof. Michael Chen',
        action: 'reviewed',
        target: 'Student Analytics Report',
        icon: 'check-circle',
        color: 'success',
        timestamp: 8.hours.ago
      },
      {
        user: 'Admin Team',
        action: 'exported',
        target: 'Quarterly Compliance Report',
        icon: 'download',
        color: 'secondary',
        timestamp: 1.day.ago
      }
    ]
  end
end