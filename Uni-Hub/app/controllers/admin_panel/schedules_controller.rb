class AdminPanel::SchedulesController < ApplicationController
  layout 'admin'
  before_action :authorize_admin!
  before_action :set_schedule, only: [:show, :edit, :update, :destroy, :approve, :cancel]

  # GET /admin/schedules
  def index
    @schedules = Schedule.includes(:instructor, :department, :active_enrollments)
                         .order(created_at: :desc)
    
    # Filters
    @schedules = @schedules.where(course: params[:course]) if params[:course].present?
    @schedules = @schedules.where(instructor_id: params[:instructor_id]) if params[:instructor_id].present?
    @schedules = @schedules.where(department_id: params[:department_id]) if params[:department_id].present?
    @schedules = @schedules.where(recurring: params[:recurring] == 'true') if params[:recurring].present?
    @schedules = @schedules.for_day(params[:day_of_week].to_i) if params[:day_of_week].present?
    
    @courses = Schedule.distinct.pluck(:course).compact.sort
    @instructors = User.where(role: ['tutor', 'admin']).order(:first_name)
    @departments = Department.order(:name)
  end

  # GET /admin/schedules/:id
  def show
    @enrollments = @schedule.active_enrollments.includes(:user).order(created_at: :asc)
  end

  # GET /admin/schedules/new
  def new
    @schedule = Schedule.new
    @courses = Course.active.includes(:department).order(:code)
    @instructors = User.where(role: ['tutor', 'admin']).order(:first_name)
    @departments = Department.active.order(:name)
  end

  # GET /admin/schedules/:id/edit
  def edit
    @courses = Course.active.includes(:department).order(:code)
    @instructors = User.where(role: ['tutor', 'admin']).order(:first_name)
    @departments = Department.active.order(:name)
  end

  # POST /admin/schedules
  def create
    @schedule = Schedule.new(schedule_params)
    @schedule.user_id = current_user.id
    
    if check_schedule_conflicts(@schedule)
      @courses = Course.active.includes(:department).order(:code)
      @instructors = User.where(role: ['tutor', 'admin']).order(:first_name)
      @departments = Department.active.order(:name)
      render :new, status: :unprocessable_entity
      return
    end
    
    if @schedule.save
      # Notify the assigned instructor
      ScheduleMailer.instructor_assigned(@schedule).deliver_later if @schedule.instructor.present?
      redirect_to admin_panel_schedule_path(@schedule), notice: 'Schedule created successfully and instructor notified.'
    else
      @courses = Course.active.includes(:department).order(:code)
      @instructors = User.where(role: ['tutor', 'admin']).order(:first_name)
      @departments = Department.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/schedules/:id
  def update
    old_instructor_id = @schedule.instructor_id
    
    if @schedule.update(schedule_params)
      # Notify if instructor changed
      if old_instructor_id != @schedule.instructor_id && @schedule.instructor.present?
        ScheduleMailer.instructor_assigned(@schedule).deliver_later
      end
      
      redirect_to admin_panel_schedule_path(@schedule), notice: 'Schedule updated successfully.'
    else
      @courses = Course.active.includes(:department).order(:code)
      @instructors = User.where(role: ['tutor', 'admin']).order(:first_name)
      @departments = Department.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/schedules/:id
  def destroy
    if @schedule.active_enrollments.exists?
      redirect_to admin_panel_schedule_path(@schedule), alert: 'Cannot delete schedule with active enrollments. Cancel enrollments first.'
    else
      @schedule.destroy
      redirect_to admin_panel_schedules_path, notice: 'Schedule deleted successfully.'
    end
  end

  # POST /admin/schedules/:id/approve
  def approve
    @schedule.update(approved_at: Time.current, approved_by_id: current_user.id)
    redirect_to admin_panel_schedules_path, notice: 'Schedule approved and activated.'
  end

  # POST /admin/schedules/:id/cancel
  def cancel
    # Optionally: notify enrolled students
    redirect_to admin_panel_schedules_path, notice: 'Schedule cancelled.'
  end

  private

  def set_schedule
    @schedule = Schedule.find(params[:id])
  end

  def schedule_params
    params.require(:schedule).permit(
      :title,
      :description,
      :course,
      :instructor_id,
      :department_id,
      :day_of_week,
      :start_time,
      :end_time,
      :room,
      :recurring,
      :color
    )
  end

  def check_schedule_conflicts(schedule)
    return false unless schedule.instructor_id.present? && schedule.day_of_week.present? && 
                        schedule.start_time.present? && schedule.end_time.present?
    
    conflicting = Schedule.where(instructor_id: schedule.instructor_id, day_of_week: schedule.day_of_week)
                         .where.not(id: schedule.id)
                         .where('start_time < ? AND end_time > ?', schedule.end_time, schedule.start_time)
    
    if conflicting.exists?
      schedule.errors.add(:base, "Schedule conflicts with another class for this instructor on #{schedule.day_name}")
      return true
    end
    
    false
  end

  def authorize_admin!
    unless user_signed_in? && current_user.admin?
      redirect_to new_admin_session_path, alert: 'Please sign in with an admin account.'
    end
  end
end
