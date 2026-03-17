class ComplianceFrameworksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_compliance_manager
  before_action :set_compliance_framework, only: [:show, :edit, :update, :destroy]
  
  def index
    @compliance_frameworks = ComplianceFramework.includes(:campus)
                                              .search(params[:search])
                                              .by_regulatory_body(params[:regulatory_body])
                                              .by_status(params[:status])
                                              .page(params[:page])
                                              .per(20)
    
    @regulatory_bodies = ComplianceFramework.distinct.pluck(:regulatory_body).compact
    @statuses = ComplianceFramework.distinct.pluck(:status).compact
    
    respond_to do |format|
      format.html
      format.json { render json: @compliance_frameworks }
      format.csv { send_data frameworks_csv, filename: "compliance_frameworks_#{Date.current}.csv" }
    end
  end
  
  def show
    @assessments = @compliance_framework.compliance_assessments
                                      .recent
                                      .limit(10)
    
    @recent_reports = @compliance_framework.compliance_reports
                                         .recent
                                         .limit(5)
    
    @compliance_summary = {
      total_assessments: @compliance_framework.compliance_assessments.count,
      passed_assessments: @compliance_framework.compliance_assessments.passed.count,
      current_score: @compliance_framework.current_compliance_score,
      next_assessment: @compliance_framework.next_assessment_date,
      status: @compliance_framework.status
    }
  end
  
  def new
    @compliance_framework = ComplianceFramework.new
    @campuses = Campus.active.order(:name)
  end
  
  def create
    @compliance_framework = ComplianceFramework.new(compliance_framework_params)
    
    if @compliance_framework.save
      redirect_to @compliance_framework, notice: 'Compliance framework was successfully created.'
    else
      @campuses = Campus.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @campuses = Campus.active.order(:name)
  end
  
  def update
    if @compliance_framework.update(compliance_framework_params)
      redirect_to @compliance_framework, notice: 'Compliance framework was successfully updated.'
    else
      @campuses = Campus.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @compliance_framework.can_be_deleted?
      @compliance_framework.destroy
      redirect_to compliance_frameworks_url, notice: 'Compliance framework was successfully deleted.'
    else
      redirect_to @compliance_framework, alert: 'Cannot delete framework with existing assessments.'
    end
  end
  
  def generate_report
    @compliance_framework = ComplianceFramework.find(params[:id])
    
    begin
      @report = ComplianceReport.generate_automated_report(
        @compliance_framework,
        params[:report_type] || 'quarterly'
      )
      
      redirect_to [@compliance_framework, @report], 
                  notice: "#{params[:report_type]&.humanize || 'Quarterly'} report generated successfully."
    rescue => e
      redirect_to @compliance_framework, 
                  alert: "Failed to generate report: #{e.message}"
    end
  end
  
  def schedule_assessment
    @compliance_framework = ComplianceFramework.find(params[:id])
    
    assessment_date = Date.parse(params[:assessment_date]) rescue Date.current + 1.week
    assessment_type = params[:assessment_type] || 'scheduled'
    
    begin
      @assessment = @compliance_framework.schedule_next_assessment!(
        assessment_date: assessment_date,
        assessment_type: assessment_type,
        assessor: current_user
      )
      
      redirect_to [@compliance_framework, @assessment],
                  notice: 'Assessment scheduled successfully.'
    rescue => e
      redirect_to @compliance_framework,
                  alert: "Failed to schedule assessment: #{e.message}"
    end
  end
  
  def compliance_dashboard
    @frameworks = ComplianceFramework.active
                                   .includes(:campus, :compliance_assessments, :compliance_reports)
    
    @dashboard_data = {
      total_frameworks: @frameworks.count,
      compliant_frameworks: @frameworks.select(&:compliant?).count,
      overdue_assessments: @frameworks.map(&:days_since_last_assessment).select { |days| days && days > 90 }.count,
      recent_reports: ComplianceReport.recent.limit(10),
      compliance_trend: calculate_compliance_trend,
      top_risks: identify_top_compliance_risks
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end
  
  def export_framework
    @compliance_framework = ComplianceFramework.find(params[:id])
    
    case params[:format]
    when 'pdf'
      redirect_to framework_pdf_path(@compliance_framework)
    when 'json'
      send_data @compliance_framework.to_json(include: [:compliance_assessments, :compliance_reports]),
                filename: "framework_#{@compliance_framework.id}_#{Date.current}.json",
                type: 'application/json'
    else
      redirect_to @compliance_framework, alert: 'Invalid export format'
    end
  end
  
  private
  
  def set_compliance_framework
    @compliance_framework = ComplianceFramework.find(params[:id])
  end
  
  def compliance_framework_params
    params.require(:compliance_framework).permit(
      :name, :description, :regulatory_body, :framework_version, :effective_date,
      :campus_id, :status, :compliance_threshold, :assessment_frequency,
      :notification_settings, requirements: [], stakeholders: []
    )
  end
  
  def require_admin_or_compliance_manager
    unless current_user.admin? || current_user.compliance_manager?
      redirect_to root_path, alert: 'Access denied. Compliance management privileges required.'
    end
  end
  
  def frameworks_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Name', 'Regulatory Body', 'Status', 'Campus', 'Compliance Score', 'Last Assessment', 'Next Assessment']
      
      @compliance_frameworks.each do |framework|
        csv << [
          framework.name,
          framework.regulatory_body,
          framework.status,
          framework.campus&.name,
          framework.current_compliance_score,
          framework.last_assessment_date,
          framework.next_assessment_date
        ]
      end
    end
  end
  
  def calculate_compliance_trend
    # Calculate compliance trend over the last 12 months
    12.times.map do |i|
      month = i.months.ago.beginning_of_month
      
      assessments = ComplianceAssessment.where(assessment_date: month..month.end_of_month)
      avg_score = assessments.average(:score) || 0
      
      {
        month: month.strftime('%b %Y'),
        average_score: avg_score.round(2),
        assessment_count: assessments.count
      }
    end.reverse
  end
  
  def identify_top_compliance_risks
    # Identify frameworks with the highest risk based on scores and overdue assessments
    ComplianceFramework.active
                      .select do |framework|
                        framework.current_compliance_score < 70 ||
                        (framework.days_since_last_assessment || 0) > 90
                      end
                      .sort_by(&:current_compliance_score)
                      .first(10)
                      .map do |framework|
                        {
                          framework: framework,
                          risk_level: calculate_risk_level(framework),
                          issues: identify_framework_issues(framework)
                        }
                      end
  end
  
  def calculate_risk_level(framework)
    score = framework.current_compliance_score
    days_overdue = [framework.days_since_last_assessment - 90, 0].max
    
    if score < 50 || days_overdue > 180
      'critical'
    elsif score < 70 || days_overdue > 90
      'high'
    elsif score < 85 || days_overdue > 30
      'medium'
    else
      'low'
    end
  end
  
  def identify_framework_issues(framework)
    issues = []
    
    issues << 'Low compliance score' if framework.current_compliance_score < 70
    issues << 'Overdue assessment' if (framework.days_since_last_assessment || 0) > 90
    issues << 'No recent reports' if framework.compliance_reports.where('created_at > ?', 6.months.ago).empty?
    issues << 'Failed recent assessments' if framework.compliance_assessments.recent.failed.exists?
    
    issues
  end
end