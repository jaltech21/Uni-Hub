class ScheduleReminderJob < ApplicationJob
  queue_as :default

  def perform(schedule_id, student_id)
    schedule = Schedule.find_by(id: schedule_id)
    student = User.find_by(id: student_id)
    
    return unless schedule && student
    
    # Only send if student is still enrolled
    return unless schedule.students.include?(student)
    
    ScheduleMailer.class_reminder(schedule, student).deliver_now
  end
end
