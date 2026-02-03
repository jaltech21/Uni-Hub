class ComplianceAssessmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_compliance_access
  before_action :set_compliance_framework, only: [:index, :new, :create]
  before_action :set_compliance_assessment, only: [:show, :edit, :update, :destroy, :complete, :approve, :reject]
  
  def index
    @assessments = @compliance_framework.compliance_assessments
                                      .includes(:assessor, :campus, :department)
                                      .by_status(params[:status])
                                      .by_type(params[:assessment_type])
                                      .recent
                                      .page(params[:page])
                                      .per(15)
    
    @assessment_stats = {
      total: @compliance_framework.compliance_assessments.count,
      completed: @compliance_framework.compliance_assessments.completed.count,
      passed: @compliance_framework.compliance_assessments.passed.count,
      pending: @compliance_framework.compliance_assessments.pending.count,
      average_score: @compliance_framework.compliance_assessments.average(:score)&.round(2) || 0
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @assessments.includes(:assessor) }
      format.csv { send_data assessments_csv, filename: "assessments_#{Date.current}.csv" }
    end
  end
  
  def show
    @audit_trails = AuditTrail.where(
      auditable_type: 'ComplianceAssessment',
      auditable_id: @assessment.id
    ).recent.limit(20)
    
    @related_assessments = @assessment.compliance_framework
                                    .compliance_assessments
                                    .where.not(id: @assessment.id)
                                    .recent
                                    .limit(5)
  end
  
  def new
    @assessment = @compliance_framework.compliance_assessments.build
    @assessors = User.where(role: ['admin', 'compliance_manager', 'department_head'])
    @campuses = Campus.active
    @departments = Department.all
  end
  
  def create
    @assessment = @compliance_framework.compliance_assessments.build(assessment_params)
    @assessment.assessor = current_user unless @assessment.assessor
    
    if @assessment.save
      # Log assessment creation
      AuditTrail.log_action(
        user: current_user,
        auditable: @assessment,
        action: 'create_assessment',
        details: {
          framework: @compliance_framework.name,
          assessment_type: @assessment.assessment_type,
          scheduled_date: @assessment.assessment_date
        }
      )
      
      redirect_to [@compliance_framework, @assessment], 
                  notice: 'Assessment was successfully scheduled.'
    else
      @assessors = User.where(role: ['admin', 'compliance_manager', 'department_head'])
      @campuses = Campus.active
      @departments = Department.all
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    authorize_assessment_modification
    @assessors = User.where(role: ['admin', 'compliance_manager', 'department_head'])
    @campuses = Campus.active
    @departments = Department.all
  end
  
  def update
    authorize_assessment_modification
    
    old_values = @assessment.attributes.dup
    
    if @assessment.update(assessment_params)
      # Log assessment update
      changes = @assessment.previous_changes.except('updated_at')
      
      if changes.any?
        AuditTrail.log_action(
          user: current_user,
          auditable: @assessment,
          action: 'update_assessment',
          details: {
            changes: changes,
            previous_values: old_values.slice(*changes.keys)
          }
        )
      end
      
      redirect_to [@assessment.compliance_framework, @assessment],
                  notice: 'Assessment was successfully updated.'
    else
      @assessors = User.where(role: ['admin', 'compliance_manager', 'department_head'])
      @campuses = Campus.active
      @departments = Department.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize_assessment_modification
    
    framework = @assessment.compliance_framework
    
    # Log assessment deletion
    AuditTrail.log_action(
      user: current_user,
      auditable: @assessment,
      action: 'delete_assessment',
      details: {
        assessment_id: @assessment.id,
        framework: framework.name,
        status: @assessment.status
      }
    )
    
    @assessment.destroy
    redirect_to framework, notice: 'Assessment was successfully deleted.'
  end
  
  def complete
    authorize_assessment_completion
    
    if params[:assessment_results].present?
      @assessment.assign_attributes(completion_params)
      
      if @assessment.complete_assessment!
        # Log assessment completion
        AuditTrail.log_action(
          user: current_user,
          auditable: @assessment,
          action: 'complete_assessment',
          details: {
            score: @assessment.score,
            status: @assessment.status,
            findings_count: @assessment.findings&.count || 0,
            recommendations_count: @assessment.recommendations&.count || 0
          }
        )
        
        redirect_to [@assessment.compliance_framework, @assessment],
                    notice: 'Assessment completed successfully.'
      else
        render :show, status: :unprocessable_entity
      end
    else
      render :show, status: :unprocessable_entity, 
             alert: 'Assessment results are required to complete the assessment.'
    end
  end
  
  def approve
    authorize_assessment_approval
    
    if @assessment.can_be_approved?
      @assessment.approve!(current_user, params[:approval_notes])
      
      # Log assessment approval
      AuditTrail.log_action(
        user: current_user,
        auditable: @assessment,
        action: 'approve_assessment',
        details: {
          approval_notes: params[:approval_notes],
          approved_at: @assessment.approved_at
        }
      )
      
      redirect_to [@assessment.compliance_framework, @assessment],
                  notice: 'Assessment approved successfully.'
    else
      redirect_to [@assessment.compliance_framework, @assessment],
                  alert: 'Assessment cannot be approved in its current state.'
    end
  end
  
  def reject
    authorize_assessment_approval
    
    if @assessment.can_be_rejected?
      @assessment.reject!(current_user, params[:rejection_reason])
      
      # Log assessment rejection
      AuditTrail.log_action(
        user: current_user,
        auditable: @assessment,
        action: 'reject_assessment',
        details: {
          rejection_reason: params[:rejection_reason],
          rejected_at: Time.current
        }
      )
      
      redirect_to [@assessment.compliance_framework, @assessment],
                  notice: 'Assessment rejected. Assessor will be notified for revision.'
    else
      redirect_to [@assessment.compliance_framework, @assessment],
                  alert: 'Assessment cannot be rejected in its current state.'
    end
  end
  
  def dashboard
    @my_assessments = ComplianceAssessment.where(assessor: current_user)
                                        .includes(:compliance_framework, :campus)
                                        .recent
                                        .limit(10)
    
    @pending_approvals = ComplianceAssessment.pending_approval
                                           .includes(:compliance_framework, :assessor)
                                           .limit(10) if can_approve_assessments?
    
    @assessment_summary = {
      total_assigned: ComplianceAssessment.where(assessor: current_user).count,
      completed_this_month: ComplianceAssessment.where(
        assessor: current_user,
        status: 'completed',
        completed_at: 1.month.ago..Time.current
      ).count,
      overdue: ComplianceAssessment.where(assessor: current_user)
                                 .where('assessment_date < ? AND status NOT IN (?)', 
                                        Date.current, ['completed', 'approved']).count,
      average_score: ComplianceAssessment.where(assessor: current_user, status: 'completed')
                                       .average(:score)&.round(2) || 0
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { assessments: @my_assessments, summary: @assessment_summary } }
    end
  end
  
  def export_assessment
    case params[:format]
    when 'pdf'
      redirect_to assessment_pdf_path(@assessment)
    when 'json'
      send_data @assessment.to_json(
        include: [:compliance_framework, :assessor, :campus, :department]
      ), filename: "assessment_#{@assessment.id}_#{Date.current}.json",
         type: 'application/json'
    else
      redirect_to [@assessment.compliance_framework, @assessment], 
                  alert: 'Invalid export format'
    end
  end
  
  private
  
  def set_compliance_framework
    @compliance_framework = ComplianceFramework.find(params[:compliance_framework_id])
  end
  
  def set_compliance_assessment
    @assessment = ComplianceAssessment.find(params[:id])
  end
  
  def assessment_params
    params.require(:compliance_assessment).permit(
      :assessment_type, :assessment_date, :campus_id, :department_id,
      :assessor_id, :description, :priority, :scheduled_by,
      requirements_checklist: [], metadata: {}
    )
  end
  
  def completion_params
    params.require(:assessment_results).permit(
      :score, :status, :completion_notes, :executive_summary,
      findings: [], recommendations: [], action_items: [], evidence: []
    )
  end
  
  def require_compliance_access
    unless current_user.admin? || current_user.compliance_manager? || 
           current_user.department_head? || current_user.compliance_assessor?
      redirect_to root_path, alert: 'Access denied. Compliance privileges required.'
    end
  end
  
  def authorize_assessment_modification
    unless can_modify_assessment?
      redirect_to [@assessment.compliance_framework, @assessment], 
                  alert: 'You do not have permission to modify this assessment.'
    end
  end
  
  def authorize_assessment_completion
    unless can_complete_assessment?
      redirect_to [@assessment.compliance_framework, @assessment],
                  alert: 'You do not have permission to complete this assessment.'
    end
  end
  
  def authorize_assessment_approval
    unless can_approve_assessments?
      redirect_to [@assessment.compliance_framework, @assessment],
                  alert: 'You do not have permission to approve assessments.'
    end
  end
  
  def can_modify_assessment?
    current_user.admin? || 
    current_user.compliance_manager? ||
    @assessment.assessor == current_user ||
    (@assessment.campus && current_user.campus == @assessment.campus && current_user.department_head?)
  end
  
  def can_complete_assessment?
    current_user.admin? ||
    current_user.compliance_manager? ||
    @assessment.assessor == current_user
  end
  
  def can_approve_assessments?
    current_user.admin? || current_user.compliance_manager?
  end
  
  def assessments_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Assessment Date', 'Type', 'Status', 'Score', 'Assessor', 'Campus', 'Department', 'Completed At']
      
      @assessments.each do |assessment|
        csv << [
          assessment.assessment_date,
          assessment.assessment_type,
          assessment.status,
          assessment.score,
          assessment.assessor&.name,
          assessment.campus&.name,
          assessment.department&.name,
          assessment.completed_at
        ]
      end
    end
  end
end