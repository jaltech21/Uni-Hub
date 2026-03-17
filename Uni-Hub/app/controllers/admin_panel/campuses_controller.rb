class Admin::CampusesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access
  before_action :set_campus, only: [:show, :edit, :update, :destroy]
  
  def index
    @campuses = Campus.includes(:university, :departments)
                     .page(params[:page])
                     .per(20)
    
    # Filters
    @campuses = @campuses.where(university_id: params[:university_id]) if params[:university_id].present?
    @campuses = @campuses.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    @universities = University.all
    @campus_statistics = Campus.campus_system_overview
  end
  
  def show
    @campus_programs = @campus.campus_programs.includes(:department, :program_director)
    @collaborations = @campus.all_collaborations.active.limit(10)
    @statistics = @campus.detailed_statistics
    @operating_hours_today = @campus.operating_hours_for_date(Date.current)
  end
  
  def new
    @campus = Campus.new
    @universities = University.all
  end
  
  def create
    @campus = Campus.new(campus_params)
    
    if @campus.save
      redirect_to admin_campus_path(@campus), 
                  notice: 'Campus was successfully created.'
    else
      @universities = University.all
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @universities = University.all
  end
  
  def update
    if @campus.update(campus_params)
      redirect_to admin_campus_path(@campus), 
                  notice: 'Campus was successfully updated.'
    else
      @universities = University.all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @campus.can_be_deleted?
      @campus.destroy
      redirect_to admin_campuses_path, 
                  notice: 'Campus was successfully deleted.'
    else
      redirect_to admin_campus_path(@campus), 
                  alert: 'Cannot delete campus with active programs or collaborations.'
    end
  end
  
  # AJAX endpoints for dashboard widgets
  def statistics
    @campus = Campus.find(params[:id])
    render json: @campus.detailed_statistics
  end
  
  def collaboration_network
    @campus = Campus.find(params[:id])
    network_data = CrossCampusCollaboration.campus_collaboration_network(@campus.id)
    render json: network_data
  end
  
  def performance_metrics
    @campus = Campus.find(params[:id])
    metrics = @campus.calculate_performance_metrics
    render json: metrics
  end
  
  def operating_hours
    @campus = Campus.find(params[:id])
    date = Date.parse(params[:date]) rescue Date.current
    hours = @campus.operating_hours_for_date(date)
    render json: { 
      date: date.iso8601,
      hours: hours,
      is_open: @campus.open_on_date?(date),
      next_opening: @campus.next_opening_time
    }
  end
  
  private
  
  def set_campus
    @campus = Campus.find(params[:id])
  end
  
  def campus_params
    params.require(:campus).permit(
      :name, :code, :university_id, :address, :city, :state, :postal_code,
      :country, :phone, :email, :website, :established_date, :campus_type,
      :total_area_sqft, :student_capacity, :latitude, :longitude,
      :description, :mission_statement, :accreditation_info,
      operating_hours: {},
      contact_persons: [],
      facilities: []
    )
  end
  
  def ensure_admin_access
    redirect_to root_path unless current_user.admin? || current_user.campus_admin?
  end
end