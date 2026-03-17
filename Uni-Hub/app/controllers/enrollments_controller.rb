class EnrollmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_enrollment, only: [:destroy]
  before_action :authorize_student!, except: [:index]

  # GET /enrollments
  def index
    if current_user.student?
      # Student sees their own enrollments
      @enrollments = current_user.enrollments.includes(:schedule).order(created_at: :desc)
      @available_schedules = Schedule.available_for_enrollment.includes(:instructor, :department).order(:course)
    elsif current_user.teacher?
      # Teacher sees enrollments for their courses
      @taught_schedules = current_user.taught_schedules.includes(:active_enrollments)
      @enrollments = Enrollment.joins(:schedule)
                               .where(schedules: { instructor_id: current_user.id })
                               .includes(:user, :schedule)
                               .order(created_at: :desc)
    else
      # Admin sees all enrollments
      @enrollments = Enrollment.includes(:user, :schedule).order(created_at: :desc)
    end
  end

  # GET /enrollments/new
  def new
    @available_schedules = Schedule.available_for_enrollment
                                   .includes(:instructor, :department)
                                   .order(:course)
    
    @current_enrollment = current_user.primary_enrollment
  end

  # POST /enrollments
  def create
    @enrollment = current_user.enrollments.build(enrollment_params)
    
    if @enrollment.save
      redirect_to enrollments_path, notice: 'Successfully enrolled in the course.'
    else
      @available_schedules = Schedule.available_for_enrollment
                                     .includes(:instructor, :department)
                                     .order(:course)
      @current_enrollment = current_user.primary_enrollment
      flash.now[:alert] = @enrollment.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /enrollments/:id
  def destroy
    if @enrollment.user_id != current_user.id && !current_user.admin?
      redirect_to enrollments_path, alert: 'You can only manage your own enrollments.'
      return
    end

    schedule_name = @enrollment.schedule.full_name
    @enrollment.destroy
    redirect_to enrollments_path, notice: "Successfully dropped #{schedule_name}."
  end

  # GET /enrollments/capacity/:schedule_id
  def capacity
    @schedule = Schedule.find(params[:schedule_id])
    render json: {
      enrolled: @schedule.active_enrollments.count,
      available_slots: @schedule.available_slots,
      has_capacity: @schedule.has_capacity?,
      percentage: @schedule.enrollment_percentage
    }
  end

  private

  def set_enrollment
    @enrollment = Enrollment.find(params[:id])
  end

  def enrollment_params
    params.require(:enrollment).permit(:schedule_id, :status)
  end

  def authorize_student!
    unless current_user.student?
      redirect_to root_path, alert: 'Only students can manage enrollments.'
    end
  end
end
