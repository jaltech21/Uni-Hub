class Admin::CrossCampusCollaborationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_collaboration, only: [:show, :edit, :update, :destroy, :add_milestone, :add_participant]
  
  def index
    @collaborations = CrossCampusCollaboration.includes(:lead_campus, :partner_campus, :project_lead)
                                             .page(params[:page])
                                             .per(20)
    
    # Filters
    @collaborations = @collaborations.by_type(params[:type]) if params[:type].present?
    @collaborations = @collaborations.by_status(params[:status]) if params[:status].present?
    @collaborations = @collaborations.by_priority(params[:priority]) if params[:priority].present?
    @collaborations = @collaborations.for_campus(params[:campus_id]) if params[:campus_id].present?
    @collaborations = @collaborations.where('title ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    @campuses = Campus.all
    @statistics = CrossCampusCollaboration.collaboration_statistics
  end
  
  def show
    @milestones = @collaboration.collaboration_milestones.includes(:collaboration_milestones)
    @participants = @collaboration.collaboration_participants.includes(:user)
    @resources = @collaboration.collaboration_resources
    @summary = @collaboration.collaboration_summary
    @performance_metrics = @collaboration.performance_metrics
  end
  
  def new
    @collaboration = CrossCampusCollaboration.new
    @campuses = Campus.all
    @potential_leads = User.where(role: ['instructor', 'admin'])
    @departments = Department.all
  end
  
  def create
    @collaboration = CrossCampusCollaboration.new(collaboration_params)
    @collaboration.project_lead = current_user if @collaboration.project_lead.nil?
    
    if @collaboration.save
      # Add project lead as participant
      @collaboration.add_participant(@collaboration.project_lead, 'lead')
      
      redirect_to admin_cross_campus_collaboration_path(@collaboration),
                  notice: 'Collaboration was successfully created.'
    else
      @campuses = Campus.all
      @potential_leads = User.where(role: ['instructor', 'admin'])
      @departments = Department.all
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @campuses = Campus.all
    @potential_leads = User.where(role: ['instructor', 'admin'])
    @departments = Department.all
  end
  
  def update
    if @collaboration.update(collaboration_params)
      redirect_to admin_cross_campus_collaboration_path(@collaboration),
                  notice: 'Collaboration was successfully updated.'
    else
      @campuses = Campus.all
      @potential_leads = User.where(role: ['instructor', 'admin'])
      @departments = Department.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @collaboration.destroy
    redirect_to admin_cross_campus_collaborations_path,
                notice: 'Collaboration was successfully deleted.'
  end
  
  def add_milestone
    milestone = @collaboration.add_milestone(
      params[:title],
      Date.parse(params[:due_date]),
      params[:description]
    )
    
    if milestone.persisted?
      render json: {
        success: true,
        milestone: {
          id: milestone.id,
          title: milestone.title,
          due_date: milestone.due_date,
          status: milestone.status
        }
      }
    else
      render json: {
        success: false,
        errors: milestone.errors.full_messages
      }
    end
  end
  
  def complete_milestone
    milestone = @collaboration.collaboration_milestones.find(params[:milestone_id])
    @collaboration.complete_milestone(milestone.id)
    
    render json: {
      success: true,
      progress_percentage: @collaboration.reload.progress_percentage
    }
  end
  
  def add_participant
    user = User.find(params[:user_id])
    role = params[:role] || 'collaborator'
    
    participant = @collaboration.add_participant(user, role)
    
    if participant.persisted?
      render json: {
        success: true,
        participant: {
          id: participant.id,
          name: user.full_name,
          role: participant.role
        }
      }
    else
      render json: {
        success: false,
        errors: participant.errors.full_messages
      }
    end
  end
  
  def remove_participant
    user = User.find(params[:user_id])
    
    if @collaboration.remove_participant(user)
      render json: { success: true }
    else
      render json: { success: false, message: 'Failed to remove participant' }
    end
  end
  
  def add_resource
    resource = @collaboration.add_resource(
      params[:resource_type],
      params[:name],
      params[:description],
      params[:url]
    )
    
    if resource.persisted?
      render json: {
        success: true,
        resource: {
          id: resource.id,
          name: resource.name,
          type: resource.resource_type
        }
      }
    else
      render json: {
        success: false,
        errors: resource.errors.full_messages
      }
    end
  end
  
  def add_expense
    amount = params[:amount].to_f
    description = params[:description]
    category = params[:category] || 'general'
    
    begin
      @collaboration.add_expense(amount, description, category)
      render json: {
        success: true,
        new_spent_amount: @collaboration.reload.spent_amount,
        remaining_budget: @collaboration.remaining_budget,
        budget_status: @collaboration.budget_status
      }
    rescue => e
      render json: {
        success: false,
        message: e.message
      }
    end
  end
  
  def collaboration_network
    campus_id = params[:campus_id]
    network_data = CrossCampusCollaboration.campus_collaboration_network(campus_id)
    render json: network_data
  end
  
  def dashboard_data
    statistics = CrossCampusCollaboration.collaboration_statistics
    recent_collaborations = CrossCampusCollaboration.recent.limit(5)
    overdue_collaborations = CrossCampusCollaboration.overdue.limit(5)
    ending_soon = CrossCampusCollaboration.ending_soon.limit(5)
    
    render json: {
      statistics: statistics,
      recent_collaborations: recent_collaborations.map(&:collaboration_summary),
      overdue_collaborations: overdue_collaborations.map(&:collaboration_summary),
      ending_soon: ending_soon.map(&:collaboration_summary)
    }
  end
  
  private
  
  def set_collaboration
    @collaboration = CrossCampusCollaboration.find(params[:id])
  end
  
  def collaboration_params
    params.require(:cross_campus_collaboration).permit(
      :title, :description, :collaboration_type, :status, :priority_level,
      :lead_campus_id, :partner_campus_id, :project_lead_id, :department_id,
      :start_date, :end_date, :budget, :objectives,
      expected_outcomes: []
    )
  end
  
  def ensure_admin_access
    redirect_to root_path unless current_user.admin? || current_user.campus_admin?
  end
end