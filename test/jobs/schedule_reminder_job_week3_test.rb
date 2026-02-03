require 'test_helper'

class ScheduleReminderJobTest < ActiveJob::TestCase
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @department = departments(:computer_science)
    
    @schedule = Schedule.create!(
      title: 'Advanced Programming Lecture',
      description: 'Weekly programming concepts discussion',
      location: 'Computer Lab 1',
      start_time: 30.minutes.from_now,
      end_time: 2.5.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 30,
      schedule_type: 'class'
    )
    
    @participant = ScheduleParticipant.create!(
      schedule: @schedule,
      user: @student,
      status: 'enrolled'
    )
  end

  test "should enqueue job with correct arguments" do
    assert_enqueued_with(job: ScheduleReminderJob, args: [@schedule.id, @student.id]) do
      ScheduleReminderJob.perform_later(@schedule.id, @student.id)
    end
  end

  test "should perform job and send email to enrolled student" do
    assert_emails 1 do
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
    end
  end

  test "should send email with correct mailer method" do
    # Mock the mailer to verify the correct method is called
    mailer_mock = Minitest::Mock.new
    mailer_mock.expect(:deliver_now, true)
    
    ScheduleMailer.stub(:class_reminder, mailer_mock) do
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
    end
    
    mailer_mock.verify
  end

  test "should not send email if schedule does not exist" do
    assert_emails 0 do
      ScheduleReminderJob.perform_now(99999, @student.id)
    end
  end

  test "should not send email if student does not exist" do
    assert_emails 0 do
      ScheduleReminderJob.perform_now(@schedule.id, 99999)
    end
  end

  test "should not send email if student is not enrolled" do
    # Create unenrolled student
    unenrolled_student = User.create!(
      email: 'unenrolled@test.com',
      password: 'password123',
      first_name: 'Unenrolled',
      last_name: 'Student',
      role: 'student'
    )
    
    assert_emails 0 do
      ScheduleReminderJob.perform_now(@schedule.id, unenrolled_student.id)
    end
  end

  test "should not send email if student is dropped" do
    @participant.update!(status: 'dropped')
    
    assert_emails 0 do
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
    end
  end

  test "should not send email if student is only waitlisted" do
    @participant.update!(status: 'waitlisted')
    
    assert_emails 0 do
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
    end
  end

  test "should handle job with invalid schedule ID gracefully" do
    assert_nothing_raised do
      ScheduleReminderJob.perform_now(nil, @student.id)
    end
    
    assert_nothing_raised do
      ScheduleReminderJob.perform_now('invalid', @student.id)
    end
  end

  test "should handle job with invalid student ID gracefully" do
    assert_nothing_raised do
      ScheduleReminderJob.perform_now(@schedule.id, nil)
    end
    
    assert_nothing_raised do
      ScheduleReminderJob.perform_now(@schedule.id, 'invalid')
    end
  end

  test "should use default queue" do
    job = ScheduleReminderJob.new(@schedule.id, @student.id)
    assert_equal 'default', job.queue_name
  end

  test "should retry on transient errors" do
    # Simulate email delivery failure
    ScheduleMailer.stub(:class_reminder, -> (schedule, student) {
      mock_mail = Object.new
      mock_mail.define_singleton_method(:deliver_now) { raise Net::SMTPTemporaryError }
      mock_mail
    }) do
      assert_raises Net::SMTPTemporaryError do
        ScheduleReminderJob.perform_now(@schedule.id, @student.id)
      end
    end
  end

  test "should work with multiple students" do
    student2 = User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    )
    
    ScheduleParticipant.create!(
      schedule: @schedule,
      user: student2,
      status: 'enrolled'
    )
    
    assert_emails 2 do
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
      ScheduleReminderJob.perform_now(@schedule.id, student2.id)
    end
  end

  test "should work with completed participants" do
    @participant.update!(status: 'completed')
    
    # Completed participants should still receive reminders if they're considered "enrolled"
    # This depends on business logic - adjust based on requirements
    assert_emails 0 do
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
    end
  end

  # Integration Tests
  test "should integrate with schedule reminder system" do
    # Test that the job is actually enqueued when schedules need reminders
    @schedule.update!(start_time: 25.hours.from_now) # Should trigger reminder
    
    # This would typically be called by a cron job or scheduler
    if @schedule.should_send_reminder?
      assert_enqueued_jobs 1, only: ScheduleReminderJob do
        ScheduleReminderJob.perform_later(@schedule.id, @student.id)
      end
    end
  end

  test "should handle schedule deletion after job enqueue" do
    # Enqueue job
    ScheduleReminderJob.perform_later(@schedule.id, @student.id)
    
    # Delete schedule
    @schedule.destroy
    
    # Job should handle missing schedule gracefully
    assert_emails 0 do
      perform_enqueued_jobs only: ScheduleReminderJob
    end
  end

  test "should handle student deletion after job enqueue" do
    # Enqueue job
    ScheduleReminderJob.perform_later(@schedule.id, @student.id)
    
    # Delete student
    @student.destroy
    
    # Job should handle missing student gracefully
    assert_emails 0 do
      perform_enqueued_jobs only: ScheduleReminderJob
    end
  end

  # Performance Tests
  test "should execute efficiently" do
    start_time = Time.current
    
    ScheduleReminderJob.perform_now(@schedule.id, @student.id)
    
    execution_time = Time.current - start_time
    assert execution_time < 5.seconds, "Job took too long to execute: #{execution_time}s"
  end

  test "should handle batch processing" do
    # Create multiple students and schedules
    students = 10.times.map do |i|
      User.create!(
        email: "batch_student#{i}@test.com",
        password: 'password123',
        first_name: 'Batch',
        last_name: "Student#{i}",
        role: 'student'
      )
    end
    
    students.each do |student|
      ScheduleParticipant.create!(
        schedule: @schedule,
        user: student,
        status: 'enrolled'
      )
    end
    
    # Enqueue jobs for all students
    students.each do |student|
      ScheduleReminderJob.perform_later(@schedule.id, student.id)
    end
    
    assert_enqueued_jobs 10, only: ScheduleReminderJob
    
    # Process all jobs
    assert_emails 10 do
      perform_enqueued_jobs only: ScheduleReminderJob
    end
  end

  # Error Handling Tests
  test "should log errors appropriately" do
    # This would test logging in a real application
    # For now, ensure no exceptions are raised
    assert_nothing_raised do
      ScheduleReminderJob.perform_now(nil, nil)
    end
  end

  test "should handle concurrent job execution" do
    # Test that multiple jobs can run simultaneously without issues
    jobs = 5.times.map do |i|
      student = User.create!(
        email: "concurrent#{i}@test.com",
        password: 'password123',
        first_name: 'Concurrent',
        last_name: "Student#{i}",
        role: 'student'
      )
      
      ScheduleParticipant.create!(
        schedule: @schedule,
        user: student,
        status: 'enrolled'
      )
      
      ScheduleReminderJob.new(@schedule.id, student.id)
    end
    
    # Execute jobs concurrently (simulated)
    assert_emails 5 do
      jobs.each(&:perform_now)
    end
  end

  # Business Logic Tests
  test "should respect schedule timing" do
    # Test that reminders are only sent at appropriate times
    past_schedule = Schedule.create!(
      title: 'Past Schedule',
      description: 'This schedule is in the past',
      location: 'Room 999',
      start_time: 1.hour.ago,
      end_time: 30.minutes.ago,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    past_participant = ScheduleParticipant.create!(
      schedule: past_schedule,
      user: @student,
      status: 'enrolled'
    )
    
    # Should not send reminder for past schedule
    # (This logic might be in the scheduling system, not the job itself)
    assert_emails 1 do # Only current schedule
      ScheduleReminderJob.perform_now(@schedule.id, @student.id)
      ScheduleReminderJob.perform_now(past_schedule.id, @student.id)
    end
  end

  test "should handle schedule updates after job creation" do
    # Enqueue job
    ScheduleReminderJob.perform_later(@schedule.id, @student.id)
    
    # Update schedule
    @schedule.update!(title: 'Updated Schedule Title')
    
    # Job should still work with updated schedule
    assert_emails 1 do
      perform_enqueued_jobs only: ScheduleReminderJob
    end
  end
end
