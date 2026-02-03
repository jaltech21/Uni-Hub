class ScheduleMailer < ApplicationMailer
  default from: 'noreply@unihub.com'

  # Send class reminder 30 minutes before class
  def class_reminder(schedule, student)
    @schedule = schedule
    @student = student
    @instructor_name = schedule.instructor ? schedule.instructor.full_name : schedule.user.full_name
    
    mail(
      to: student.email,
      subject: "Reminder: #{@schedule.title} in 30 minutes"
    )
  end

  # Notify students when a schedule is updated
  def schedule_updated(schedule, student, changes)
    @schedule = schedule
    @student = student
    @changes = changes
    @instructor_name = schedule.instructor ? schedule.instructor.full_name : schedule.user.full_name
    
    mail(
      to: student.email,
      subject: "Schedule Update: #{@schedule.title}"
    )
  end

  # Notify students when a schedule is cancelled/deleted
  def schedule_cancelled(schedule_data, student)
    @schedule_title = schedule_data[:title]
    @schedule_course = schedule_data[:course]
    @schedule_time = schedule_data[:time]
    @schedule_day = schedule_data[:day]
    @student = student
    
    mail(
      to: student.email,
      subject: "Class Cancelled: #{@schedule_title}"
    )
  end

  # Confirm enrollment to a student
  def enrollment_confirmation(schedule, student)
    @schedule = schedule
    @student = student
    @instructor_name = schedule.instructor ? schedule.instructor.full_name : schedule.user.full_name
    
    mail(
      to: student.email,
      subject: "Enrollment Confirmed: #{@schedule.title}"
    )
  end

  # Notify student when unenrolled
  def unenrollment_notification(schedule, student)
    @schedule = schedule
    @student = student
    @instructor_name = schedule.instructor ? schedule.instructor.full_name : schedule.user.full_name
    
    mail(
      to: student.email,
      subject: "Unenrolled from: #{@schedule.title}"
    )
  end
end
