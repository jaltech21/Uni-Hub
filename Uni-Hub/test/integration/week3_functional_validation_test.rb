require 'test_helper'

class Week3FunctionalValidationTest < ActiveSupport::TestCase
  def setup
    # Clean up previous test data
    University.destroy_all
    Department.destroy_all
    User.destroy_all
    
    # Create university and department with unique identifiers
    @university = University.create!(
      name: "Test University #{rand(10000)}",
      code: "TU#{rand(10000)}",
      active: true
    )
    
    @department = Department.create!(
      name: "Computer Science #{rand(10000)}",
      code: "CS#{rand(10000)}",
      university: @university,
      active: true
    )
    
    # Create users with unique emails
    @teacher = User.create!(
      email: "teacher#{rand(10000)}@test.edu",
      password: 'password123',
      first_name: 'John',
      last_name: 'Teacher',
      role: 'teacher',
      department: @department
    )
    
    @student = User.create!(
      email: "student#{rand(10000)}@test.edu",
      password: 'password123',
      first_name: 'Jane',
      last_name: 'Student',
      role: 'student',
      department: @department
    )
  end

  test "Week 3 Assignment Management System - Core Functionality" do
    # Create assignment with correct attributes
    assignment = Assignment.create!(
      title: 'Programming Assignment 1',
      description: 'Create a Ruby application demonstrating OOP principles',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'project'
    )
    
    assert assignment.persisted?, "Assignment should be created successfully"
    assert_equal 'Programming Assignment 1', assignment.title
    assert_equal @teacher, assignment.user
    assert_equal 100, assignment.points
    assert_equal 'project', assignment.category
    
    # Create submission
    submission = Submission.create!(
      assignment: assignment,
      user: @student,
      content: 'Here is my Ruby application implementation...',
      submitted_at: Time.current
    )
    
    assert submission.persisted?, "Submission should be created successfully"
    assert_equal assignment, submission.assignment
    assert_equal @student, submission.user
    assert submission.submitted_at.present?
    
    # Grade submission
    submission.update!(
      grade: 85,
      feedback: 'Good work! Consider adding more comments.',
      graded_at: Time.current
    )
    
    assert_equal 85, submission.grade
    assert submission.graded_at.present?
    assert submission.feedback.present?
    
    puts "✅ Assignment Management System: Core functionality verified"
  end

  test "Week 3 Student Scheduling System - Core Functionality" do
    # Create schedule with correct attributes
    schedule = Schedule.create!(
      title: 'Advanced Programming Lecture',
      description: 'Weekly programming concepts discussion',
      course: 'CS301',
      day_of_week: 1, # Monday
      start_time: Time.parse('10:00 AM'),
      end_time: Time.parse('11:30 AM'),
      room: 'Computer Lab 1',
      user: @teacher,
      instructor: @teacher,
      department: @department
    )
    
    assert schedule.persisted?, "Schedule should be created successfully"
    assert_equal 'Advanced Programming Lecture', schedule.title
    assert_equal @teacher, schedule.user
    assert_equal 'CS301', schedule.course
    assert_equal 1, schedule.day_of_week
    assert_equal 'Computer Lab 1', schedule.room
    
    # Create schedule participant
    participant = ScheduleParticipant.create!(
      schedule: schedule,
      user: @student,
      role: 'student'
    )
    
    assert participant.persisted?, "Schedule participant should be created successfully"
    assert_equal schedule, participant.schedule
    assert_equal @student, participant.user
    assert_equal 'student', participant.role
    
    # Test schedule methods
    assert_equal 'Monday', schedule.day_name
    assert schedule.duration_in_minutes > 0
    assert schedule.has_participant?(@student)
    
    puts "✅ Student Scheduling System: Core functionality verified"
  end

  test "Week 3 Note-taking System - Core Functionality" do
    # Create note with correct attributes
    note = Note.create!(
      title: 'Programming Best Practices',
      content: 'Important concepts for clean code development and maintainability',
      user: @student,
      department: @department
    )
    
    assert note.persisted?, "Note should be created successfully"
    assert_equal 'Programming Best Practices', note.title
    assert_equal @student, note.user
    assert note.content.present?
    
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
      shared_with: @teacher,
      shared_by: @student,
      permission: 'view'
    )
    
    assert note_share.persisted?, "Note share should be created successfully"
    assert_equal 'view', note_share.permission
    assert note.shared_with?(@teacher)
    
    # Test note search
    found_notes = Note.search('programming')
    assert_includes found_notes, note
    
    puts "✅ Note-taking System: Core functionality verified"
  end

  test "Week 3 Digital Attendance System - Core Functionality" do
    # Create schedule for attendance
    schedule = Schedule.create!(
      title: 'Attendance Test Class',
      course: 'CS101',
      day_of_week: 2, # Tuesday  
      start_time: Time.parse('2:00 PM'),
      end_time: Time.parse('3:30 PM'),
      room: 'Room 101',
      user: @teacher,
      instructor: @teacher,
      department: @department
    )
    
    # Create attendance list
    attendance_list = AttendanceList.create!(
      schedule: schedule,
      opened_at: Time.current
    )
    
    assert attendance_list.persisted?, "Attendance list should be created successfully"
    assert attendance_list.totp_secret.present?, "TOTP secret should be generated"
    
    # Generate and verify TOTP code
    totp_code = attendance_list.generate_totp_code
    assert_match /^\d{6}$/, totp_code, "TOTP code should be 6 digits"
    assert attendance_list.verify_totp_code(totp_code), "TOTP code should be valid"
    
    # Record attendance
    attendance_record = AttendanceRecord.create!(
      attendance_list: attendance_list,
      user: @student,
      recorded_at: Time.current
    )
    
    assert attendance_record.persisted?, "Attendance record should be created successfully"
    assert_equal attendance_list, attendance_record.attendance_list
    assert_equal @student, attendance_record.user
    assert attendance_record.recorded_at.present?
    
    # Test QR code generation
    qr_code_data = attendance_list.generate_qr_code_data
    assert qr_code_data.include?(totp_code), "QR code should contain TOTP code"
    
    puts "✅ Digital Attendance System: Core functionality verified"
  end

  test "Week 3 Email System - Core Functionality" do
    # Create schedule for email testing
    schedule = Schedule.create!(
      title: 'Email Test Class',
      course: 'CS102',
      day_of_week: 3, # Wednesday
      start_time: Time.parse('1:00 PM'),
      end_time: Time.parse('2:30 PM'),
      room: 'Room 202',
      user: @teacher,
      instructor: @teacher,
      department: @department
    )
    
    # Test class reminder email
    email = ScheduleMailer.class_reminder(schedule, @student)
    
    assert_equal [@student.email], email.to
    assert_match /Reminder/, email.subject
    assert_match schedule.title, email.body.to_s
    assert_match @student.first_name, email.body.to_s
    
    # Test enrollment confirmation email  
    confirmation_email = ScheduleMailer.enrollment_confirmation(schedule, @student)
    assert_match /Enrollment Confirmed/, confirmation_email.subject
    assert_match schedule.title, confirmation_email.body.to_s
    
    # Test schedule update email
    changes = { 'room' => ['Room 202', 'Room 203'] }
    update_email = ScheduleMailer.schedule_update(schedule, @student, changes)
    assert_match /Schedule Update/, update_email.subject
    assert_match 'Room 203', update_email.body.to_s
    
    # Test cancellation email
    cancellation_email = ScheduleMailer.schedule_cancellation(schedule, @student, 'Emergency situation')
    assert_match /CANCELLED/, cancellation_email.subject
    assert_match 'Emergency situation', cancellation_email.body.to_s
    
    puts "✅ Email System: Core functionality verified"
  end

  test "Week 3 Background Jobs - Core Functionality" do
    # Create schedule for job testing
    schedule = Schedule.create!(
      title: 'Job Test Class',
      course: 'CS103',
      day_of_week: 4, # Thursday
      start_time: Time.parse('3:00 PM'),
      end_time: Time.parse('4:30 PM'),
      room: 'Room 303',
      user: @teacher,
      instructor: @teacher,
      department: @department
    )
    
    # Test job enqueuing
    assert_enqueued_jobs 0
    
    ScheduleReminderJob.perform_later(schedule.id, @student.id)
    
    assert_enqueued_jobs 1, only: ScheduleReminderJob
    
    # Test job execution
    assert_emails 1 do
      ScheduleReminderJob.perform_now(schedule.id, @student.id)
    end
    
    puts "✅ Background Jobs: Core functionality verified"
  end

  test "Week 3 Security Features - Core Functionality" do
    # Test TOTP security
    schedule = Schedule.create!(
      title: 'Security Test',
      course: 'CS104',
      day_of_week: 5, # Friday
      start_time: Time.parse('11:00 AM'),
      end_time: Time.parse('12:30 PM'),
      room: 'Room 404',
      user: @teacher,
      instructor: @teacher,
      department: @department
    )
    
    attendance_list = AttendanceList.create!(
      schedule: schedule,
      opened_at: Time.current
    )
    
    # Test TOTP code generation and verification
    code1 = attendance_list.generate_totp_code
    code2 = attendance_list.generate_totp_code
    
    # Should be same within time window
    assert_equal code1, code2, "TOTP codes should be consistent within time window"
    
    # Test data validation
    invalid_assignment = Assignment.new(
      title: '',  # Required field
      points: -10  # Invalid value
    )
    
    refute invalid_assignment.valid?, "Invalid assignment should not be valid"
    assert invalid_assignment.errors[:title].present?, "Title errors should be present"
    
    # Test user authentication requirements
    assert @teacher.role == 'teacher', "Teacher should have correct role"
    assert @student.role == 'student', "Student should have correct role"
    
    puts "✅ Security Features: Core functionality verified"
  end

  test "Week 3 System Integration - Complete Workflow" do
    puts "\n🔄 Testing complete Week 3 workflow integration..."
    
    # 1. Teacher creates assignment
    assignment = Assignment.create!(
      title: 'Integration Test Assignment',
      description: 'Complete project assignment',
      due_date: 2.weeks.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'project'
    )
    
    # 2. Teacher creates schedule
    schedule = Schedule.create!(
      title: 'Assignment Discussion',
      description: 'Review assignment requirements',
      course: 'CS201',
      day_of_week: 1, # Monday
      start_time: Time.parse('2:00 PM'),
      end_time: Time.parse('3:30 PM'),
      room: 'Classroom 101',
      user: @teacher,
      instructor: @teacher,
      department: @department
    )
    
    # 3. Student enrolls in schedule
    participant = ScheduleParticipant.create!(
      schedule: schedule,
      user: @student,
      role: 'student'
    )
    
    # 4. Student creates study notes
    note = Note.create!(
      title: 'Assignment Notes',
      content: 'Key points from the assignment discussion and requirements',
      user: @student,
      department: @department
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
      content: 'My complete project submission with all requirements',
      submitted_at: Time.current
    )
    
    # 7. Teacher grades submission
    submission.update!(
      grade: 90,
      feedback: 'Excellent work!',
      graded_at: Time.current
    )
    
    # Verify complete workflow
    assert assignment.persisted?, "Assignment should be created"
    assert schedule.persisted?, "Schedule should be created"
    assert participant.persisted?, "Participation should be recorded"
    assert note.persisted?, "Note should be created"
    assert attendance_record.persisted?, "Attendance should be recorded"
    assert submission.persisted?, "Submission should be created"
    assert_equal 90, submission.grade, "Submission should be graded"
    
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
    
    puts "✅ System Integration: Complete workflow verified"
    puts "📊 Week 3 Summary:"
    puts "   - Assignment Management: Functional ✅"
    puts "   - Digital Attendance with TOTP: Functional ✅"  
    puts "   - Student Scheduling: Functional ✅"
    puts "   - Note-taking with Collaboration: Functional ✅"
    puts "   - Background Jobs & Email: Functional ✅"
    puts "   - Security Features: Functional ✅"
    puts "   - System Integration: Functional ✅"
  end
end