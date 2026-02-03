require 'test_helper'

class ScheduleMailerTest < ActionMailer::TestCase
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @department = departments(:computer_science)
    
    @schedule = Schedule.create!(
      title: 'Advanced Programming Lecture',
      description: 'Weekly programming concepts discussion with hands-on exercises',
      location: 'Computer Lab 1',
      start_time: 2.hours.from_now,
      end_time: 4.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 30,
      schedule_type: 'class',
      notification_preferences: { 
        reminder_enabled: true, 
        reminder_hours: 24 
      }
    )
    
    @participant = ScheduleParticipant.create!(
      schedule: @schedule,
      user: @student,
      status: 'enrolled'
    )
  end

  # Class Reminder Tests
  test "class_reminder should create email with correct headers" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ['noreply@uni-hub.edu'], email.from
    assert_equal [@student.email], email.to
    assert_match /Reminder.*Advanced Programming Lecture/, email.subject
  end

  test "class_reminder should include schedule details in body" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    assert_match @schedule.title, email.body.to_s
    assert_match @schedule.description, email.body.to_s
    assert_match @schedule.location, email.body.to_s
    assert_match @teacher.full_name, email.body.to_s
  end

  test "class_reminder should format time correctly" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    # Should include formatted start and end times
    assert_match @schedule.start_time.strftime('%B %d, %Y'), email.body.to_s
    assert_match @schedule.start_time.strftime('%l:%M %p'), email.body.to_s
    assert_match @schedule.end_time.strftime('%l:%M %p'), email.body.to_s
  end

  test "class_reminder should personalize message" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    assert_match @student.first_name, email.body.to_s
    assert_match "Hi #{@student.first_name}", email.body.to_s
  end

  test "class_reminder should include action links" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    # Should include links to view schedule or update preferences
    assert_match /view.*schedule/i, email.body.to_s
    assert_match schedule_url(@schedule), email.body.to_s
  end

  # Enrollment Confirmation Tests
  test "enrollment_confirmation should create email with correct headers" do
    email = ScheduleMailer.enrollment_confirmation(@schedule, @student)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ['noreply@uni-hub.edu'], email.from
    assert_equal [@student.email], email.to
    assert_match /Enrollment Confirmed.*Advanced Programming Lecture/, email.subject
  end

  test "enrollment_confirmation should include enrollment details" do
    email = ScheduleMailer.enrollment_confirmation(@schedule, @student)
    
    assert_match "successfully enrolled", email.body.to_s
    assert_match @schedule.title, email.body.to_s
    assert_match @schedule.location, email.body.to_s
    assert_match "enrollment is confirmed", email.body.to_s
  end

  test "enrollment_confirmation should include next steps" do
    email = ScheduleMailer.enrollment_confirmation(@schedule, @student)
    
    # Should provide guidance on what to do next
    assert_match /what.*next/i, email.body.to_s
    assert_match /calendar/i, email.body.to_s
  end

  test "enrollment_confirmation should include cancellation info" do
    email = ScheduleMailer.enrollment_confirmation(@schedule, @student)
    
    # Should explain how to cancel if needed
    assert_match /cancel/i, email.body.to_s
    assert_match /drop/i, email.body.to_s
  end

  # Schedule Update Tests
  test "schedule_update should create email with correct headers" do
    changes = { 
      'location' => ['Computer Lab 1', 'Computer Lab 2'],
      'start_time' => [@schedule.start_time, @schedule.start_time + 1.hour]
    }
    
    email = ScheduleMailer.schedule_update(@schedule, @student, changes)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ['noreply@uni-hub.edu'], email.from
    assert_equal [@student.email], email.to
    assert_match /Schedule Update.*Advanced Programming Lecture/, email.subject
  end

  test "schedule_update should highlight changes" do
    changes = { 
      'location' => ['Computer Lab 1', 'Computer Lab 2'],
      'start_time' => [@schedule.start_time, @schedule.start_time + 1.hour]
    }
    
    email = ScheduleMailer.schedule_update(@schedule, @student, changes)
    
    assert_match "Computer Lab 1", email.body.to_s
    assert_match "Computer Lab 2", email.body.to_s
    assert_match /location.*changed/i, email.body.to_s
    assert_match /time.*changed/i, email.body.to_s
  end

  test "schedule_update should handle multiple changes" do
    changes = { 
      'location' => ['Computer Lab 1', 'Computer Lab 2'],
      'start_time' => [@schedule.start_time, @schedule.start_time + 1.hour],
      'description' => ['Old description', 'New updated description']
    }
    
    email = ScheduleMailer.schedule_update(@schedule, @student, changes)
    
    # Should list all changes clearly
    changes.each do |field, values|
      assert_match field.humanize, email.body.to_s
      assert_match values[0].to_s, email.body.to_s
      assert_match values[1].to_s, email.body.to_s
    end
  end

  test "schedule_update should provide context" do
    changes = { 'location' => ['Computer Lab 1', 'Computer Lab 2'] }
    
    email = ScheduleMailer.schedule_update(@schedule, @student, changes)
    
    assert_match /updated.*schedule/i, email.body.to_s
    assert_match @teacher.full_name, email.body.to_s
    assert_match /contact.*instructor/i, email.body.to_s
  end

  # Schedule Cancellation Tests
  test "schedule_cancellation should create email with correct headers" do
    reason = "Instructor unavailable due to emergency"
    
    email = ScheduleMailer.schedule_cancellation(@schedule, @student, reason)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ['noreply@uni-hub.edu'], email.from
    assert_equal [@student.email], email.to
    assert_match /CANCELLED.*Advanced Programming Lecture/, email.subject
    assert_match /urgent/i, email.subject
  end

  test "schedule_cancellation should explain cancellation" do
    reason = "Instructor unavailable due to emergency"
    
    email = ScheduleMailer.schedule_cancellation(@schedule, @student, reason)
    
    assert_match "cancelled", email.body.to_s
    assert_match reason, email.body.to_s
    assert_match /sorry.*inconvenience/i, email.body.to_s
  end

  test "schedule_cancellation should provide next steps" do
    reason = "Technical difficulties in the lab"
    
    email = ScheduleMailer.schedule_cancellation(@schedule, @student, reason)
    
    # Should explain what happens next
    assert_match /reschedule/i, email.body.to_s
    assert_match /contact/i, email.body.to_s
    assert_match /notification/i, email.body.to_s
  end

  test "schedule_cancellation should handle missing reason" do
    email = ScheduleMailer.schedule_cancellation(@schedule, @student, nil)
    
    # Should still work without a specific reason
    assert_match "cancelled", email.body.to_s
    assert_no_match "null", email.body.to_s
    assert_no_match "nil", email.body.to_s
  end

  # Template and Layout Tests
  test "all emails should use consistent layout" do
    emails = [
      ScheduleMailer.class_reminder(@schedule, @student),
      ScheduleMailer.enrollment_confirmation(@schedule, @student),
      ScheduleMailer.schedule_update(@schedule, @student, {'location' => ['A', 'B']}),
      ScheduleMailer.schedule_cancellation(@schedule, @student, "Test reason")
    ]
    
    emails.each do |email|
      # Should include consistent branding
      assert_match /Uni-Hub/i, email.body.to_s
      assert_match /university/i, email.body.to_s
      
      # Should include unsubscribe link
      assert_match /unsubscribe/i, email.body.to_s
      
      # Should include contact information
      assert_match /support/i, email.body.to_s
    end
  end

  test "emails should be mobile-friendly" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    # Should have responsive design elements
    assert_match /viewport/i, email.body.to_s
    assert_match /max-width/i, email.body.to_s
  end

  test "emails should include security headers" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    # Check for security-related headers or content
    assert_match @student.email, email.body.to_s
    
    # Should not include sensitive information inappropriately
    refute_match /password/i, email.body.to_s
    refute_match /secret/i, email.body.to_s
  end

  # Personalization Tests
  test "should handle different user roles appropriately" do
    admin = User.create!(
      email: 'admin@test.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      role: 'admin'
    )
    
    email = ScheduleMailer.class_reminder(@schedule, admin)
    
    # Should still work for different user types
    assert_match admin.first_name, email.body.to_s
    assert_equal [admin.email], email.to
  end

  test "should handle users with missing names gracefully" do
    user_no_name = User.create!(
      email: 'noname@test.com',
      password: 'password123',
      first_name: '',
      last_name: '',
      role: 'student'
    )
    
    email = ScheduleMailer.class_reminder(@schedule, user_no_name)
    
    # Should have fallback for missing names
    assert_match /student/i, email.body.to_s
    refute_match /Hi ,/, email.body.to_s
  end

  # Integration Tests
  test "should work with different schedule types" do
    lab_schedule = Schedule.create!(
      title: 'Lab Session',
      description: 'Hands-on laboratory work',
      location: 'Lab 2',
      start_time: 3.hours.from_now,
      end_time: 5.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 15,
      schedule_type: 'lab'
    )
    
    email = ScheduleMailer.class_reminder(lab_schedule, @student)
    
    assert_match 'Lab Session', email.body.to_s
    assert_match 'laboratory', email.body.to_s
  end

  test "should handle special characters in schedule data" do
    special_schedule = Schedule.create!(
      title: 'C++ & Data Structures',
      description: 'Advanced topics: pointers, references & memory management',
      location: 'Room #301-A',
      start_time: 2.hours.from_now,
      end_time: 4.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'lecture'
    )
    
    email = ScheduleMailer.class_reminder(special_schedule, @student)
    
    # Should handle special characters properly
    assert_match 'C++', email.body.to_s
    assert_match '#301-A', email.body.to_s
    assert_match '&amp;', email.body.to_s
  end

  # Performance Tests
  test "should render emails efficiently" do
    start_time = Time.current
    
    email = ScheduleMailer.class_reminder(@schedule, @student)
    email.body.to_s # Force rendering
    
    render_time = Time.current - start_time
    assert render_time < 1.second, "Email took too long to render: #{render_time}s"
  end

  test "should handle batch email generation" do
    # Create multiple students
    students = 5.times.map do |i|
      User.create!(
        email: "batch#{i}@test.com",
        password: 'password123',
        first_name: 'Batch',
        last_name: "Student#{i}",
        role: 'student'
      )
    end
    
    start_time = Time.current
    
    emails = students.map do |student|
      ScheduleMailer.class_reminder(@schedule, student)
    end
    
    generation_time = Time.current - start_time
    assert generation_time < 5.seconds, "Batch generation took too long: #{generation_time}s"
    
    # Verify all emails were created properly
    emails.each_with_index do |email, i|
      assert_equal [students[i].email], email.to
      assert_match students[i].first_name, email.body.to_s
    end
  end

  # Error Handling Tests
  test "should handle missing schedule gracefully" do
    # This might not be directly testible if mailer expects valid objects
    # but we can test that the mailer doesn't break with minimal data
    
    minimal_schedule = Schedule.new(
      title: 'Minimal Schedule',
      location: 'TBD',
      start_time: Time.current,
      end_time: 1.hour.from_now
    )
    
    assert_nothing_raised do
      email = ScheduleMailer.class_reminder(minimal_schedule, @student)
      email.body.to_s
    end
  end

  test "should handle network issues gracefully" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    
    # Simulate network failure during delivery
    Net::SMTP.stub(:start, -> (*args) { raise Net::SMTPTemporaryError }) do
      assert_raises Net::SMTPTemporaryError do
        email.deliver_now
      end
    end
  end

  # Accessibility Tests
  test "emails should be accessible" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    body = email.body.to_s
    
    # Should have proper alt text for images
    if body.include?('<img')
      assert_match /alt=/i, body
    end
    
    # Should have good contrast and readable fonts
    assert_match /font-family/i, body
    
    # Should have semantic HTML structure
    assert_match /<h[1-6]/i, body
  end

  # Localization Tests (if supported)
  test "should support different locales" do
    I18n.with_locale(:es) do
      email = ScheduleMailer.class_reminder(@schedule, @student)
      
      # If localization is implemented, should use appropriate language
      # For now, just ensure email still works
      assert_not_nil email.body.to_s
      assert email.body.to_s.length > 0
    end
  end

  # Security Tests
  test "should not expose sensitive data in emails" do
    email = ScheduleMailer.class_reminder(@schedule, @student)
    body = email.body.to_s
    
    # Should not include sensitive system information
    refute_match /password/i, body
    refute_match /token/i, body
    refute_match /secret/i, body
    refute_match /api.*key/i, body
    
    # Should not include other users' information
    other_student = User.create!(
      email: 'other@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    refute_match other_student.email, body
    refute_match other_student.first_name, body
  end

  test "should validate email addresses" do
    invalid_user = User.new(
      email: 'invalid-email',
      first_name: 'Invalid',
      last_name: 'User'
    )
    
    # Should handle invalid email addresses gracefully
    assert_nothing_raised do
      email = ScheduleMailer.class_reminder(@schedule, invalid_user)
      # Note: Actual delivery would fail, but email generation should work
    end
  end
end
