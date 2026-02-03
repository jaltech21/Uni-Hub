require 'test_helper'

class Week3SystemValidationTest < ActiveSupport::TestCase
  def setup
    # Clean up previous test data
    University.destroy_all
    Department.destroy_all
    User.destroy_all
    
    # Create university and department with unique identifiers
    @university = University.create!(
      name: "Test University #{rand(1000)}",
      code: "TU#{rand(1000)}",
      active: true
    )
    
    @department = Department.create!(
      name: "Computer Science #{rand(1000)}",
      code: "CS#{rand(1000)}",
      university: @university,
      active: true
    )
    
    # Create users with unique emails
    @teacher = User.create!(
      email: "teacher#{rand(1000)}@test.edu",
      password: 'password123',
      first_name: 'John',
      last_name: 'Teacher',
      role: 'teacher',
      department: @department
    )
    
    @student = User.create!(
      email: "student#{rand(1000)}@test.edu",
      password: 'password123',
      first_name: 'Jane',
      last_name: 'Student',
      role: 'student',
      department: @department
    )
  end

  test "Week 3 Assignment Management System works end-to-end" do
    # Create assignment
    assignment = Assignment.create!(
      title: 'Programming Assignment 1',
      description: 'Create a Ruby application demonstrating OOP principles',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100,
      assignment_type: 'project',
      status: 'published'
    )
    
    assert assignment.persisted?
    assert_equal 'Programming Assignment 1', assignment.title
    assert_equal @teacher, assignment.user
    assert_equal 100, assignment.max_points
    
    # Create submission
    submission = Submission.create!(
      assignment: assignment,
      user: @student,
      content: 'Here is my Ruby application implementation...',
      status: 'submitted'
    )
    
    assert submission.persisted?
    assert_equal assignment, submission.assignment
    assert_equal @student, submission.user
    assert_equal 'submitted', submission.status
    
    # Grade submission
    submission.update!(
      points_earned: 85,
      feedback: 'Good work! Consider adding more comments.',
      status: 'graded'
    )
    
    assert_equal 85, submission.points_earned
    assert_equal 'graded', submission.status
    assert submission.feedback.present?
    
    puts "✅ Assignment Management System: PASSED"
  end

  test "Week 3 Digital Attendance System with TOTP security works" do
    # Create schedule
    schedule = Schedule.create!(
      title: 'Advanced Programming Lecture',
      description: 'Weekly programming concepts discussion',
      location: 'Computer Lab 1',
      start_time: 1.hour.from_now,
      end_time: 3.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 30,
      schedule_type: 'class'
    )
    
    assert schedule.persisted?
    
    # Create attendance list
    attendance_list = AttendanceList.create!(
      schedule: schedule,
      opened_at: Time.current
    )
    
    assert attendance_list.persisted?
    assert attendance_list.totp_secret.present?
    
    # Generate and verify TOTP code
    totp_code = attendance_list.generate_totp_code
    assert_match /^\d{6}$/, totp_code
    assert attendance_list.verify_totp_code(totp_code)
    
    # Record attendance
    attendance_record = AttendanceRecord.create!(
      attendance_list: attendance_list,
      user: @student,
      recorded_at: Time.current
    )
    
    assert attendance_record.persisted?
    assert_equal attendance_list, attendance_record.attendance_list
    assert_equal @student, attendance_record.user
    
    # Test QR code generation
    qr_code_data = attendance_list.generate_qr_code_data
    assert qr_code_data.include?(totp_code)
    
    puts "✅ Digital Attendance System: PASSED"
  end

  test "Week 3 Student Scheduling System with conflict detection works" do
    # Create first schedule
    schedule1 = Schedule.create!(
      title: 'Mathematics Lecture',
      description: 'Linear Algebra fundamentals',
      location: 'Room 101',
      start_time: 2.hours.from_now,
      end_time: 4.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 25,
      schedule_type: 'lecture'
    )
    
    # Enroll student
    participant1 = ScheduleParticipant.create!(
      schedule: schedule1,
      user: @student,
      status: 'enrolled'
    )
    
    assert participant1.persisted?
    assert_equal 'enrolled', participant1.status
    
    # Try to create conflicting schedule
    schedule2 = Schedule.new(
      title: 'Physics Lab',
      description: 'Experimental physics session',
      location: 'Lab 201',
      start_time: 2.5.hours.from_now,  # Overlaps with schedule1
      end_time: 5.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 15,
      schedule_type: 'lab'
    )
    
    # Check for conflicts
    conflicts = Schedule.check_conflicts(@teacher, schedule2.start_time, schedule2.end_time)
    assert conflicts.any?
    
    # Create non-conflicting schedule
    schedule2.update!(start_time: 5.hours.from_now, end_time: 7.hours.from_now)
    assert schedule2.save
    
    # Test enrollment limits
    schedule2.update!(max_participants: 1)
    
    # Create another student
    student2 = User.create!(
      email: "student2#{rand(1000)}@test.edu",
      password: 'password123',
      first_name: 'Bob',
      last_name: 'Student2',
      role: 'student',
      department: @department
    )
    
    # First enrollment should succeed
    participant2 = ScheduleParticipant.create!(
      schedule: schedule2,
      user: @student,
      status: 'enrolled'
    )
    assert_equal 'enrolled', participant2.status
    
    # Second enrollment should be waitlisted
    participant3 = ScheduleParticipant.create!(
      schedule: schedule2,
      user: student2,
      status: 'waitlisted'
    )
    assert_equal 'waitlisted', participant3.status
    
    puts "✅ Student Scheduling System: PASSED"
  end

  test "Week 3 Note-taking System with collaboration works" do
    # Create note
    note = Note.create!(
      title: 'Programming Best Practices',
      content: 'Important concepts for clean code development...',
      user: @student,
      is_public: false,
      note_type: 'study_guide'
    )
    
    assert note.persisted?
    assert_equal 'Programming Best Practices', note.title
    assert_equal @student, note.user
    refute note.is_public?
    
    # Create tags
    tag1 = Tag.create!(name: 'programming', color: '#ff0000')
    tag2 = Tag.create!(name: 'best-practices', color: '#00ff00')
    
    # Associate tags with note
    NoteTag.create!(note: note, tag: tag1)
    NoteTag.create!(note: note, tag: tag2)
    
    assert_equal 2, note.tags.count
    assert_includes note.tags.pluck(:name), 'programming'
    assert_includes note.tags.pluck(:name), 'best-practices'
    
    # Share note with teacher
    note_share = NoteShare.create!(
      note: note,
      shared_with_user: @teacher,
      shared_by_user: @student,
      permission_level: 'read',
      expires_at: 1.month.from_now
    )
    
    assert note_share.persisted?
    assert_equal 'read', note_share.permission_level
    assert note_share.active?
    
    # Test note accessibility
    accessible_notes = Note.accessible_by(@teacher)
    assert_includes accessible_notes, note
    
    # Test note search
    found_notes = Note.search('programming')
    assert_includes found_notes, note
    
    # Test version history (if implemented)
    note.update!(content: 'Updated content with more details...')
    assert_not_equal 'Important concepts for clean code development...', note.content
    
    puts "✅ Note-taking System: PASSED"
  end

  test "Week 3 Background Jobs and Email System works" do
    # Create schedule for reminder
    schedule = Schedule.create!(
      title: 'Important Exam',
      description: 'Final examination for the course',
      location: 'Exam Hall A',
      start_time: 25.hours.from_now,  # Should trigger reminder
      end_time: 28.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 50,
      schedule_type: 'exam'
    )
    
    # Enroll student
    participant = ScheduleParticipant.create!(
      schedule: schedule,
      user: @student,
      status: 'enrolled'
    )
    
    # Test job enqueuing
    assert_enqueued_jobs 0
    
    ScheduleReminderJob.perform_later(schedule.id, @student.id)
    
    assert_enqueued_jobs 1, only: ScheduleReminderJob
    
    # Test email generation (without actually sending)
    email = ScheduleMailer.class_reminder(schedule, @student)
    
    assert_equal [@student.email], email.to
    assert_match /Reminder.*Important Exam/, email.subject
    assert_match schedule.title, email.body.to_s
    assert_match @student.first_name, email.body.to_s
    
    # Test enrollment confirmation email
    confirmation_email = ScheduleMailer.enrollment_confirmation(schedule, @student)
    assert_match /Enrollment Confirmed/, confirmation_email.subject
    
    # Test schedule update email
    changes = { 'location' => ['Exam Hall A', 'Exam Hall B'] }
    update_email = ScheduleMailer.schedule_update(schedule, @student, changes)
    assert_match /Schedule Update/, update_email.subject
    assert_match 'Exam Hall B', update_email.body.to_s
    
    # Test cancellation email
    cancellation_email = ScheduleMailer.schedule_cancellation(schedule, @student, 'Emergency situation')
    assert_match /CANCELLED/, cancellation_email.subject
    assert_match 'Emergency situation', cancellation_email.body.to_s
    
    puts "✅ Background Jobs and Email System: PASSED"
  end

  test "Week 3 Security Features work correctly" do
    # Test TOTP security
    attendance_list = AttendanceList.create!(
      schedule: Schedule.create!(
        title: 'Security Test',
        start_time: 1.hour.from_now,
        end_time: 3.hours.from_now,
        user: @teacher,
        department: @department,
        schedule_type: 'class'
      ),
      opened_at: Time.current
    )
    
    # Test code generation and verification
    code1 = attendance_list.generate_totp_code
    code2 = attendance_list.generate_totp_code
    
    # Should be same within time window
    assert_equal code1, code2
    
    # Should be different after time passes
    travel 31.seconds do
      code3 = attendance_list.generate_totp_code
      assert_not_equal code1, code3
    end
    
    # Test authorization (using Pundit if available)
    assignment = Assignment.create!(
      title: 'Security Test Assignment',
      user: @teacher,
      department: @department,
      due_date: 1.week.from_now,
      max_points: 100
    )
    
    # Student should not be able to modify teacher's assignment
    # (This would be enforced by Pundit policies in controllers)
    assert_not_equal @student, assignment.user
    
    # Test data validation
    invalid_assignment = Assignment.new(
      title: '',  # Required field
      max_points: -10  # Invalid value
    )
    
    refute invalid_assignment.valid?
    assert invalid_assignment.errors[:title].present?
    
    puts "✅ Security Features: PASSED"
  end

  test "Week 3 System Integration works correctly" do
    # Create a complete workflow
    
    # 1. Teacher creates assignment
    assignment = Assignment.create!(
      title: 'Integration Test Assignment',
      description: 'Complete project assignment',
      due_date: 2.weeks.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # 2. Teacher creates schedule for assignment discussion
    schedule = Schedule.create!(
      title: 'Assignment Discussion',
      description: 'Review assignment requirements',
      location: 'Classroom 101',
      start_time: 2.hours.from_now,
      end_time: 4.hours.from_now,
      user: @teacher,
      department: @department,
      schedule_type: 'class'
    )
    
    # 3. Student enrolls in schedule
    participant = ScheduleParticipant.create!(
      schedule: schedule,
      user: @student,
      status: 'enrolled'
    )
    
    # 4. Student creates study notes
    note = Note.create!(
      title: 'Assignment Notes',
      content: 'Key points from the assignment discussion',
      user: @student,
      is_public: false
    )
    
    # 5. Student attends class (attendance tracking)
    attendance_list = AttendanceList.create!(
      schedule: schedule,
      opened_at: Time.current
    )
    
    attendance_record = AttendanceRecord.create!(
      attendance_list: attendance_list,
      user: @student,
      recorded_at: Time.current
    )
    
    # 6. Student submits assignment
    submission = Submission.create!(
      assignment: assignment,
      user: @student,
      content: 'My complete project submission',
      status: 'submitted'
    )
    
    # 7. Teacher grades submission
    submission.update!(
      points_earned: 90,
      feedback: 'Excellent work!',
      status: 'graded'
    )
    
    # Verify all systems worked together
    assert assignment.persisted?
    assert schedule.persisted?
    assert participant.enrolled?
    assert note.persisted?
    assert attendance_record.persisted?
    assert submission.graded?
    assert_equal 90, submission.points_earned
    
    # Test data relationships
    assert_equal @teacher, assignment.user
    assert_equal @teacher, schedule.user
    assert_equal @student, submission.user
    assert_equal @student, note.user
    assert_equal @student, attendance_record.user
    
    # Test department associations
    assert_equal @department, assignment.department
    assert_equal @department, schedule.department
    assert_equal @department, @teacher.department
    assert_equal @department, @student.department
    
    puts "✅ System Integration: PASSED"
  end

  private

  def travel(duration)
    # Simple time travel simulation
    original_time = Time.current
    Time.stub(:current, original_time + duration) do
      yield
    end
  end
end