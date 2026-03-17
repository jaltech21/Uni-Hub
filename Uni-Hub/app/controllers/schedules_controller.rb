class SchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_schedule, only: [:show, :edit, :update]
  before_action :authorize_teacher_or_admin!, only: [:edit, :update]
  before_action :authorize_schedule_access!, only: [:show, :edit, :update]

  # GET /schedules
  def index
    if current_user.teacher?
      # Teachers see schedules assigned to them by admin
      @schedules = Schedule.where(instructor_id: current_user.id)
                          .includes(:instructor, :schedule_participants, :students)
                          .by_day_and_time
    elsif current_user.admin?
      # Admins see all schedules
      @schedules = Schedule.includes(:instructor, :schedule_participants, :students)
                          .by_day_and_time
    else
      # Students see schedules they're enrolled in
      @schedules = current_user.enrolled_schedules
                               .includes(:instructor, :schedule_participants)
                               .by_day_and_time
    end
  end

  # GET /schedules/:id
  def show
    @participants = @schedule.schedule_participants.includes(:user).active
    @students = @schedule.students
  end

  # GET /schedules/:id/edit
  # Teachers can only edit certain fields, not create or delete schedules
  def edit
    unless current_user.admin?
      # Verify teacher owns this schedule
      unless @schedule.instructor_id == current_user.id
        redirect_to schedules_path, alert: 'You can only edit schedules assigned to you.'
        return
      end
    end
  end

  # PATCH/PUT /schedules/:id
  # Teachers can only update limited fields
  def update
    unless current_user.admin?
      # Verify teacher owns this schedule
      unless @schedule.instructor_id == current_user.id
        redirect_to schedules_path, alert: 'You can only edit schedules assigned to you.'
        return
      end
    end

    # Use different params based on role
    update_params = current_user.admin? ? schedule_params : teacher_allowed_params

    if @schedule.update(update_params)
      redirect_to @schedule, notice: 'Schedule updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /schedules/:id
  def destroy
    # Store schedule data before destruction for notification
    schedule_data = {
      title: @schedule.title,
      course: @schedule.course,
      day: @schedule.day_name,
      time: @schedule.formatted_time_range
    }
    enrolled_students = @schedule.students.to_a
    
    @schedule.destroy
    
    # Send cancellation notifications to all enrolled students
    send_cancellation_notifications(schedule_data, enrolled_students)
    
    redirect_to schedules_path, notice: 'Schedule was successfully deleted.'
  end

  # GET /schedules/check_conflicts (AJAX endpoint)
  def check_conflicts_ajax
    schedule = Schedule.new(schedule_params)
    schedule.instructor_id = params[:instructor_id] || current_user.id
    schedule.id = params[:id] if params[:id].present?
    
    conflicts = find_conflicting_schedules(schedule)
    
    render json: {
      has_conflicts: conflicts.any?,
      conflicts: conflicts.map do |s|
        {
          id: s.id,
          title: s.title,
          course: s.course,
          time_range: s.formatted_time_range,
          room: s.room
        }
      end
    }
  end

  private

  def set_schedule
    @schedule = Schedule.find(params[:id])
  end

  def authorize_teacher_or_admin!
    unless current_user.teacher? || current_user.admin?
      redirect_to root_path, alert: 'Access denied.'
    end
  end

  def authorize_schedule_access!
    # Admins can access all schedules
    return if current_user.admin?
    
    # Teachers can access schedules they're instructing
    if current_user.teacher?
      unless @schedule.instructor_id == current_user.id
        redirect_to schedules_path, alert: "You can only access schedules assigned to you."
      end
    else
      # Students can access schedules they're enrolled in
      unless @schedule.has_participant?(current_user)
        redirect_to schedules_path, alert: "You are not enrolled in this schedule."
      end
    end
  end

  def schedule_params
    params.require(:schedule).permit(
      :title, :description, :course, :day_of_week, 
      :start_time, :end_time, :room, :instructor_id,
      :recurring, :color, :department_id
    )
  end

  def teacher_allowed_params
    # Teachers can only update these fields (not core schedule details)
    params.require(:schedule).permit(
      :description,
      :color
    )
  end

  def check_conflicts(schedule)
    conflicts = find_conflicting_schedules(schedule)
    
    if conflicts.any?
      schedule.errors.add(:base, "Schedule conflicts with: #{conflicts.first.title} (#{conflicts.first.formatted_time_range})")
      return true
    end
    
    false
  end

  def find_conflicting_schedules(schedule)
    return [] unless schedule.instructor_id.present? && schedule.day_of_week.present?
    
    Schedule.where(instructor_id: schedule.instructor_id, day_of_week: schedule.day_of_week)
            .where.not(id: schedule.id)
            .where('start_time < ? AND end_time > ?', schedule.end_time, schedule.start_time)
  end

  def add_students_to_schedule(schedule, student_ids)
    return unless student_ids.present?
    
    student_ids = student_ids.reject(&:blank?)
    student_ids.each do |student_id|
      schedule.schedule_participants.create(user_id: student_id, role: 'student')
    end
  end

  def update_students_in_schedule(schedule, student_ids)
    return [[], []] unless student_ids.present?
    
    student_ids = student_ids.reject(&:blank?)
    existing_ids = schedule.schedule_participants.students.pluck(:user_id)
    
    # Remove students no longer selected
    to_remove = existing_ids - student_ids.map(&:to_i)
    removed_students = User.where(id: to_remove).to_a
    schedule.schedule_participants.where(user_id: to_remove, role: 'student').destroy_all
    
    # Add new students
    to_add = student_ids.map(&:to_i) - existing_ids
    added_students = User.where(id: to_add).to_a
    to_add.each do |student_id|
      schedule.schedule_participants.create(user_id: student_id, role: 'student')
    end
    
    [removed_students, added_students]
  end

  def detect_schedule_changes(old_attrs, schedule)
    changes = {}
    
    if old_attrs[:day_of_week] != schedule.day_of_week
      old_day_name = Date::DAYNAMES[old_attrs[:day_of_week]]
      changes[:day] = [old_day_name, schedule.day_name]
    end
    
    if old_attrs[:start_time] != schedule.start_time || old_attrs[:end_time] != schedule.end_time
      old_time = "#{old_attrs[:start_time].strftime('%I:%M %p')} - #{old_attrs[:end_time].strftime('%I:%M %p')}"
      changes[:time] = [old_time, schedule.formatted_time_range]
    end
    
    if old_attrs[:room] != schedule.room
      changes[:room] = [old_attrs[:room], schedule.room]
    end
    
    if old_attrs[:title] != schedule.title
      changes[:title] = [old_attrs[:title], schedule.title]
    end
    
    if old_attrs[:course] != schedule.course
      changes[:course] = [old_attrs[:course], schedule.course]
    end
    
    changes
  end

  def send_enrollment_confirmations(schedule)
    schedule.students.each do |student|
      ScheduleMailer.enrollment_confirmation(schedule, student).deliver_later
    end
  end

  def send_update_notifications(schedule, changes)
    schedule.students.each do |student|
      ScheduleMailer.schedule_updated(schedule, student, changes).deliver_later
    end
  end

  def send_cancellation_notifications(schedule_data, students)
    students.each do |student|
      ScheduleMailer.schedule_cancelled(schedule_data, student).deliver_later
    end
  end

  def send_enrollment_change_notifications(schedule, added_students, removed_students)
    # Send enrollment confirmations to newly added students
    added_students.each do |student|
      ScheduleMailer.enrollment_confirmation(schedule, student).deliver_later
    end
    
    # Send unenrollment notifications to removed students
    removed_students.each do |student|
      ScheduleMailer.unenrollment_notification(schedule, student).deliver_later
    end
  end

  # GET /schedules/browse
  def browse
    # Show all available schedules that the student can enroll in
    @enrolled_schedules = current_user.enrolled_schedules.includes(:instructor)
    enrolled_schedule_ids = @enrolled_schedules.pluck(:id)
    @available_schedules = Schedule.where.not(id: enrolled_schedule_ids)
                                  .includes(:instructor, :schedule_participants)
                                  .by_day_and_time
  end

  # POST /schedules/:id/enroll
  def enroll
    @schedule = Schedule.find(params[:id])
    
    # Check if already enrolled
    if @schedule.students.include?(current_user)
      redirect_to browse_schedules_path, alert: 'You are already enrolled in this class.'
      return
    end
    
    # Check for schedule conflicts
    if current_user.has_schedule_conflict?(@schedule)
      redirect_to browse_schedules_path, alert: 'This schedule conflicts with one of your existing classes.'
      return
    end
    
    # Create enrollment
    participant = ScheduleParticipant.new(
      schedule: @schedule,
      user: current_user,
      participant_type: 'student',
      enrollment_status: 'enrolled'
    )
    
    if participant.save
      redirect_to schedules_path, notice: 'Successfully enrolled in the class!'
    else
      redirect_to browse_schedules_path, alert: 'Failed to enroll in the class.'
    end
  end

  # DELETE /schedules/:id/unenroll
  def unenroll
    @schedule = Schedule.find(params[:id])
    participant = @schedule.schedule_participants.find_by(user: current_user)
    
    if participant&.destroy
      redirect_to schedules_path, notice: 'Successfully unenrolled from the class.'
    else
      redirect_to schedules_path, alert: 'Failed to unenroll from the class.'
    end
  end
end
