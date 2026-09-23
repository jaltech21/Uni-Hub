class AttendanceListsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_teacher, only: [:new, :edit, :create, :update, :destroy, :refresh_code]
  before_action :set_attendance_list, only: [:show, :edit, :update, :destroy, :refresh_code]
  before_action :prevent_caching, only: [:refresh_code]

  def index
    @attendance_lists = lists_for(current_user).order(created_at: :desc)
    @attendance_list = @attendance_lists.first
  end

  def new
    @attendance_list = current_user.attendance_lists.new
  end

  def edit
  end

  def create
    @attendance_list = current_user.attendance_lists.new(attendance_list_params)
    if @attendance_list.save
      notify_enrolled_students(@attendance_list)
      redirect_to attendance_list_attendance_records_path(@attendance_list), notice: 'Attendance list was successfully created. Now, add records.'
    else
      render :new
    end
  end

  def show
  end

  def update
    if @attendance_list.update(attendance_list_params)
      redirect_to attendance_list_path(@attendance_list), notice: 'Attendance list was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @attendance_list.destroy
    redirect_to attendance_lists_url, notice: 'Attendance list was successfully deleted.', status: :see_other
  end

  def refresh_code
    render layout: false
  end

  private

  def prevent_caching
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  # Teachers (and tutors) see their own lists. Enrolled students see lists
  # tied to the schedules they are enrolled in, including legacy lists
  # created by those schedules' instructors for today or later.
  def lists_for(user)
    if user.teacher?
      user.attendance_lists
    else
      schedule_ids = user.enrolled_schedules.distinct.pluck(:id)
      instructor_ids = Schedule.where(id: schedule_ids).distinct.pluck(:user_id, :instructor_id).flatten.compact
      lists = AttendanceList.where(schedule_id: schedule_ids)
      legacy = AttendanceList.where(user_id: instructor_ids)
                              .where("date >= ?", Date.current)
                              .where(schedule_id: nil)
      lists.or(legacy)
    end
  end

  def set_attendance_list
    @attendance_list = lists_for(current_user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to attendance_lists_url, alert: 'Attendance list not found or you are not authorized to access it.'
  end

  def notify_enrolled_students(attendance_list)
    return unless attendance_list.schedule.present?
    attendance_list.schedule.enrolled_students.find_each do |student|
      Notification.notify_attendance_created(student, attendance_list)
    end
  end

  def attendance_list_params
    # Only permitting title, description, date, and schedule_id (no secret_key/special_code is mass-assignable)
    params.require(:attendance_list).permit(:title, :description, :date, :schedule_id)
  end

  def authorize_teacher
    unless current_user&.teacher?
      redirect_to root_path, alert: 'You are not authorized to access this page.'
    end
  end
end
