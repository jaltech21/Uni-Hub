class ComplianceReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_compliance_access
  before_action :set_compliance_framework, only: [:index, :new, :create]
  before_action :set_compliance_report, only: [:show, :edit, :update, :destroy, :publish, :export]
  
  def index
    @reports = @compliance_framework.compliance_reports
                                  .includes(:generated_by, :compliance_framework)
                                  .by_type(params[:report_type])
                                  .by_status(params[:status])
                                  .recent
                                  .page(params[:page])
                                  .per(15)
    
    @report_stats = {
      total: @compliance_framework.compliance_reports.count,
      published: @compliance_framework.compliance_reports.published.count,
      draft: @compliance_framework.compliance_reports.where(status: 'draft').count,
      auto_generated: @compliance_framework.compliance_reports.auto_generated.count
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @reports }
      format.csv { send_data reports_csv, filename: "compliance_reports_#{Date.current}.csv" }
    end
  end
  
  def show
    @assessment_summary = {
      total_assessments: @report.total_assessments,
      passed_assessments: @report.passed_assessments,
      compliance_rate: @report.key_metrics&.dig('compliance_rate') || 0,
      trend_direction: @report.key_metrics&.dig('trend_direction') || 'stable'
    }
    
    @key_findings = @report.key_findings
    @trend_data = @report.compliance_score_trend
    
    respond_to do |format|
      format.html
      format.json { render json: @report.to_json(include: :compliance_framework) }
      format.pdf { render_pdf }
    end
  end
  
  def new
    @report = @compliance_framework.compliance_reports.build
    @report.period_start = 3.months.ago.beginning_of_month
    @report.period_end = Date.current.end_of_month
    @campuses = Campus.active
  end
  
  def create
    @report = @compliance_framework.compliance_reports.build(report_params)
    @report.generated_by = current_user
    
    if @report.save
      # Generate content asynchronously if requested
      if params[:generate_content] == 'true'
        @report.generate_content!
        @report.update!(status: 'completed')
      end
      
      # Log report creation
      AuditTrail.log_action(
        user: current_user,
        auditable: @report,
        action: 'create_report',
        details: {
          framework: @compliance_framework.name,
          report_type: @report.report_type,
          period: @report.period_description
        }
      )
      
      redirect_to [@compliance_framework, @report], 
                  notice: 'Compliance report was successfully created.'
    else
      @campuses = Campus.active
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    authorize_report_modification
    @campuses = Campus.active
  end
  
  def update
    authorize_report_modification
    
    old_status = @report.status
    
    if @report.update(report_params)
      # Regenerate content if requested
      if params[:regenerate_content] == 'true'
        @report.generate_content!
      end
      
      # Log significant changes
      if @report.status != old_status || params[:regenerate_content] == 'true'
        AuditTrail.log_action(
          user: current_user,
          auditable: @report,
          action: 'update_report',
          details: {
            status_change: old_status != @report.status ? "#{old_status} → #{@report.status}" : nil,
            content_regenerated: params[:regenerate_content] == 'true'
          }
        )
      end
      
      redirect_to [@report.compliance_framework, @report],
                  notice: 'Report was successfully updated.'
    else
      @campuses = Campus.active
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize_report_modification
    
    unless @report.published?
      framework = @report.compliance_framework
      
      # Log report deletion
      AuditTrail.log_action(
        user: current_user,
        auditable: @report,
        action: 'delete_report',
        details: {
          report_id: @report.id,
          report_type: @report.report_type,
          framework: framework.name
        }
      )
      
      @report.destroy
      redirect_to framework, notice: 'Report was successfully deleted.'
    else
      redirect_to [@report.compliance_framework, @report],
                  alert: 'Cannot delete published reports.'
    end
  end
  
  def publish
    authorize_report_publication
    
    if @report.can_be_published?
      if @report.publish!(current_user)
        # Log report publication
        AuditTrail.log_action(
          user: current_user,
          auditable: @report,
          action: 'publish_report',
          details: {
            published_at: @report.published_at,
            report_type: @report.report_type,
            compliance_score: @report.overall_compliance_score
          }
        )
        
        # Send notifications to stakeholders
        send_publication_notifications
        
        redirect_to [@report.compliance_framework, @report],
                    notice: 'Report published successfully. Stakeholders have been notified.'
      else
        redirect_to [@report.compliance_framework, @report],
                    alert: 'Failed to publish report.'
      end
    else
      redirect_to [@report.compliance_framework, @report],
                  alert: 'Report must be completed with an executive summary before publication.'
    end
  end
  
  def export
    case params[:format]
    when 'pdf'
      result = @report.export_to_pdf
      if result[:success]
        send_file result[:file_path], 
                  filename: "compliance_report_#{@report.id}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      else
        redirect_to [@report.compliance_framework, @report],
                    alert: "Export failed: #{result[:message]}"
      end
      
    when 'csv'
      result = @report.export_to_csv
      if result[:success]
        send_file result[:file_path],
                  filename: "compliance_report_#{@report.id}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      else
        redirect_to [@report.compliance_framework, @report],
                    alert: "Export failed: #{result[:message]}"
      end
      
    when 'json'
      send_data @report.to_json(
        include: {
          compliance_framework: { only: [:name, :regulatory_body] },
          generated_by: { only: [:name, :email] }
        },
        methods: [:period_description, :key_findings, :compliance_score_trend]
      ), filename: "compliance_report_#{@report.id}_#{Date.current}.json",
         type: 'application/json',
         disposition: 'attachment'
         
    else
      redirect_to [@report.compliance_framework, @report],
                  alert: 'Invalid export format'
    end
    
    # Log export action
    AuditTrail.log_action(
      user: current_user,
      auditable: @report,
      action: 'export_report',
      details: {
        export_format: params[:format],
        exported_at: Time.current
      }
    )
  end
  
  def generate_automated
    @framework = ComplianceFramework.find(params[:compliance_framework_id])
    
    begin
      @report = ComplianceReport.generate_automated_report(
        @framework, 
        params[:report_type] || 'quarterly'
      )
      
      # Log automated generation
      AuditTrail.log_action(
        user: current_user,
        auditable: @report,
        action: 'generate_automated_report',
        details: {
          framework: @framework.name,
          report_type: @report.report_type,
          auto_generated: true
        }
      )
      
      redirect_to [@framework, @report],
                  notice: "#{@report.report_type.humanize} report generated successfully."
    rescue => e
      redirect_to @framework,
                  alert: "Failed to generate automated report: #{e.message}"
    end
  end
  
  def dashboard
    @recent_reports = ComplianceReport.includes(:compliance_framework, :generated_by)
                                    .recent
                                    .limit(10)
    
    @report_summary = {
      total_reports: ComplianceReport.count,
      published_this_month: ComplianceReport.published
                                          .where(published_at: 1.month.ago..Time.current)
                                          .count,
      draft_reports: ComplianceReport.where(status: 'draft').count,
      auto_generated_reports: ComplianceReport.auto_generated.count,
      average_compliance_score: ComplianceReport.where.not(overall_compliance_score: nil)
                                              .average(:overall_compliance_score)&.round(2) || 0
    }
    
    @compliance_trends = calculate_compliance_trends
    @framework_performance = analyze_framework_performance
    
    respond_to do |format|
      format.html
      format.json { 
        render json: { 
          reports: @recent_reports, 
          summary: @report_summary,
          trends: @compliance_trends
        } 
      }
    end
  end
  
  private
  
  def set_compliance_framework
    @compliance_framework = ComplianceFramework.find(params[:compliance_framework_id])
  end
  
  def set_compliance_report
    @report = ComplianceReport.find(params[:id])
  end
  
  def report_params
    params.require(:compliance_report).permit(
      :report_type, :period_start, :period_end, :campus_id,
      :executive_summary, :report_format, :auto_generated,
      :status, key_metrics: {}
    )
  end
  
  def require_compliance_access
    unless current_user.admin? || current_user.compliance_manager?
      redirect_to root_path, alert: 'Access denied. Compliance management privileges required.'
    end
  end
  
  def authorize_report_modification
    unless can_modify_report?
      redirect_to [@report.compliance_framework, @report],
                  alert: 'You do not have permission to modify this report.'
    end
  end
  
  def authorize_report_publication
    unless can_publish_reports?
      redirect_to [@report.compliance_framework, @report],
                  alert: 'You do not have permission to publish reports.'
    end
  end
  
  def can_modify_report?
    current_user.admin? || 
    current_user.compliance_manager? ||
    @report.generated_by == current_user
  end
  
  def can_publish_reports?
    current_user.admin? || current_user.compliance_manager?
  end
  
  def send_publication_notifications
    # Placeholder for notification system
    # This would typically send emails to stakeholders
    puts "Sending publication notifications for report #{@report.id}"
  end
  
  def render_pdf
    # Placeholder for PDF rendering
    # This would typically use a gem like Prawn or wicked_pdf
    redirect_to [@report.compliance_framework, @report],
                alert: 'PDF export not yet implemented'
  end
  
  def reports_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Report Type', 'Period', 'Status', 'Compliance Score', 'Generated By', 'Published At', 'Total Assessments']
      
      @reports.each do |report|
        csv << [
          report.report_type,
          report.period_description,
          report.status,
          report.overall_compliance_score,
          report.generated_by&.name,
          report.published_at,
          report.total_assessments
        ]
      end
    end
  end
  
  def calculate_compliance_trends
    # Calculate compliance trends over the last 12 months
    12.times.map do |i|
      month = i.months.ago.beginning_of_month
      
      reports = ComplianceReport.published
                               .where(period_end: month..month.end_of_month)
      
      {
        month: month.strftime('%b %Y'),
        average_score: reports.average(:overall_compliance_score)&.round(2) || 0,
        report_count: reports.count,
        published_count: reports.count
      }
    end.reverse
  end
  
  def analyze_framework_performance
    # Analyze performance across different compliance frameworks
    ComplianceFramework.active.map do |framework|
      recent_reports = framework.compliance_reports
                               .published
                               .where(published_at: 6.months.ago..Time.current)
      
      {
        framework: framework,
        avg_compliance_score: recent_reports.average(:overall_compliance_score)&.round(2) || 0,
        total_reports: recent_reports.count,
        trend: calculate_framework_trend(framework)
      }
    end.sort_by { |f| f[:avg_compliance_score] }.reverse
  end
  
  def calculate_framework_trend(framework)
    recent_scores = framework.compliance_reports
                            .published
                            .where(published_at: 3.months.ago..Time.current)
                            .order(:published_at)
                            .pluck(:overall_compliance_score)
                            .compact
    
    return 'stable' if recent_scores.count < 2
    
    if recent_scores.last > recent_scores.first
      'improving'
    elsif recent_scores.last < recent_scores.first
      'declining'  
    else
      'stable'
    end
  end
end