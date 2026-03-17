namespace :schedules do
  desc "Send reminders for classes starting in 30 minutes"
  task send_reminders: :environment do
    puts "Checking for upcoming classes..."
    
    # Get current day of week (0-6)
    current_day = Time.current.wday
    
    # Get time 30 minutes from now
    reminder_time = 30.minutes.from_now
    
    # Find all recurring schedules for today
    schedules = Schedule.where(day_of_week: current_day, recurring: true)
    
    schedules.each do |schedule|
      # Check if class starts in approximately 30 minutes (within 5 minute window)
      start_datetime = Time.current.change(
        hour: schedule.start_time.hour,
        min: schedule.start_time.min
      )
      
      time_until_class = start_datetime - Time.current
      
      # Send reminder if class starts between 25-35 minutes from now
      if time_until_class.between?(25.minutes, 35.minutes)
        puts "Sending reminders for: #{schedule.title} (#{schedule.course})"
        
        schedule.students.each do |student|
          ScheduleReminderJob.perform_later(schedule.id, student.id)
          puts "  - Reminder queued for #{student.email}"
        end
      end
    end
    
    puts "Reminder check complete."
  end
end
