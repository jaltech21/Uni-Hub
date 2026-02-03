class AssignmentsController < ApplicationController
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]
  before_action :authorize_teacher!, only: [:new, :create, :edit, :update, :destroy]
  before_action :check_ownership, only: [:edit, :update, :destroy]

  # GET /assignments
  def index
    # Filter by schedule if provided
    if params[:schedule_id].present?
      @schedule = Schedule.find(params[:schedule_id])
      authorize @schedule, :show?
      @assignments = @schedule.assignments.includes(:submissions, :user).order(created_at: :desc)
    elsif current_user.teacher?
      # Teacher sees assignments from their taught schedules
      @assignments = current_user.visible_assignments.includes(:submissions, :user, :schedule).order(created_at: :desc)
    else
      # Student sees assignments from their enrolled schedule
      @assignments = current_user.visible_assignments.includes(:submissions, :user, :schedule).order(due_date: :asc)
    end
  end

  def show
    authorize @assignment
  end

  # GET /assignments/new
  def new
    @assignment = Assignment.new
    # Only show schedules the teacher is teaching
    @available_schedules = current_user.taught_schedules.order(:course_code)
    authorize @assignment
  end

  def edit
    @available_schedules = current_user.taught_schedules.order(:course_code)
    authorize @assignment
  end

  # POST /assignments
  def create
    @assignment = current_user.assignments.build(assignment_params)
    authorize @assignment

    # Verify teacher owns the schedule
    if @assignment.schedule.present? && @assignment.schedule.instructor_id != current_user.id
      redirect_to new_assignment_path, alert: 'You can only create assignments for courses you teach.'
      return
    end

    if @assignment.save
      # Notify enrolled students about new assignment
      notify_enrolled_students_of_assignment(@assignment)
      redirect_to @assignment, notice: 'Assignment was successfully created.'
    else
      @available_schedules = current_user.taught_schedules.order(:course_code)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @assignment

    # Verify teacher owns the schedule if changing it
    if assignment_params[:schedule_id].present?
      schedule = Schedule.find(assignment_params[:schedule_id])
      if schedule.instructor_id != current_user.id
        redirect_to edit_assignment_path(@assignment), alert: 'You can only assign to courses you teach.'
        return
      end
    end

    if @assignment.update(assignment_params)
      redirect_to @assignment, notice: 'Assignment was successfully updated.'
    else
      @available_schedules = current_user.taught_schedules.order(:course_code)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @assignment
    
    # Get stats before deletion for the notice message
    submissions_count = @assignment.submissions.count
    graded_count = @assignment.submissions.graded.count
    
    @assignment.destroy
    
    redirect_to assignments_url, 
                notice: "Assignment deleted successfully. #{submissions_count} submission#{'s' if submissions_count != 1} and #{graded_count} grade#{'s' if graded_count != 1} were also removed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_assignment
    @assignment = Assignment.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def assignment_params
    params.require(:assignment).permit(
      :title, 
      :description, 
      :due_date, 
      :points,
      :category,
      :grading_criteria,
      :allow_resubmission,
      :course_name,
      :schedule_id,
      files: []
    )
  end

  def authorize_teacher!
    unless current_user.teacher?
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
  end

  def check_ownership
    unless @assignment.user_id == current_user.id
      redirect_to assignments_path, alert: "You can only modify your own assignments."
    end
  end
  
  def notify_enrolled_students_of_assignment(assignment)
    return unless assignment.schedule.present?
    
    assignment.schedule.enrolled_students.find_each do |student|
      Notification.notify_assignment_created(student, assignment)
    end
  end
end
