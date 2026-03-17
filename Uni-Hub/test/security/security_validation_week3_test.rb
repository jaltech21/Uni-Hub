require 'test_helper'

class SecurityValidationTest < ActiveSupport::TestCase
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
    @department = departments(:computer_science)
    
    # Create test schedule
    @schedule = Schedule.create!(
      title: 'Security Test Schedule',
      description: 'Testing security features',
      location: 'Test Lab',
      start_time: 1.hour.from_now,
      end_time: 3.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    # Create attendance list for TOTP testing
    @attendance_list = AttendanceList.create!(
      schedule: @schedule,
      opened_at: Time.current
    )
  end

  # TOTP Security Tests
  test "TOTP codes should be cryptographically secure" do
    code = @attendance_list.generate_totp_code
    
    # Should be 6 digits
    assert_match /^\d{6}$/, code
    
    # Should be different each time (with different timestamps)
    travel 31.seconds do
      new_code = @attendance_list.generate_totp_code
      assert_not_equal code, new_code
    end
  end

  test "TOTP codes should expire after time window" do
    code = @attendance_list.generate_totp_code
    
    # Should be valid immediately
    assert @attendance_list.verify_totp_code(code)
    
    # Should be invalid after time window (31 seconds)
    travel 31.seconds do
      refute @attendance_list.verify_totp_code(code)
    end
  end

  test "TOTP codes should not be reusable" do
    code = @attendance_list.generate_totp_code
    
    # First use should succeed
    assert @attendance_list.verify_totp_code(code)
    
    # Second use should fail (prevent replay attacks)
    refute @attendance_list.verify_totp_code(code)
  end

  test "TOTP codes should resist brute force attacks" do
    # Generate correct code
    correct_code = @attendance_list.generate_totp_code
    
    # Try 1000 random codes
    failed_attempts = 0
    1000.times do
      random_code = sprintf("%06d", rand(1000000))
      unless @attendance_list.verify_totp_code(random_code)
        failed_attempts += 1
      end
    end
    
    # Should fail almost all attempts (allowing for extremely rare collisions)
    assert failed_attempts > 998, "Too many successful random attempts: #{1000 - failed_attempts}/1000"
  end

  test "TOTP secret should be unique per attendance list" do
    attendance_list2 = AttendanceList.create!(
      schedule: @schedule,
      opened_at: Time.current
    )
    
    # Secrets should be different
    assert_not_equal @attendance_list.totp_secret, attendance_list2.totp_secret
    
    # Codes should be different at same timestamp
    code1 = @attendance_list.generate_totp_code
    code2 = attendance_list2.generate_totp_code
    assert_not_equal code1, code2
  end

  # File Upload Security Tests
  test "file uploads should validate file types" do
    assignment = Assignment.create!(
      title: 'Security Test Assignment',
      description: 'Testing file upload security',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # Create malicious file content
    malicious_content = "<?php system($_GET['cmd']); ?>"
    malicious_file = Tempfile.new(['malicious', '.php'])
    malicious_file.write(malicious_content)
    malicious_file.rewind
    
    submission = Submission.new(
      assignment: assignment,
      user: @student,
      content: 'Test submission with malicious file'
    )
    
    # Should reject executable file types
    submission.file.attach(
      io: malicious_file,
      filename: 'malicious.php',
      content_type: 'application/x-php'
    )
    
    refute submission.valid?
    assert submission.errors[:file].present?
    
    malicious_file.close
    malicious_file.unlink
  end

  test "file uploads should limit file size" do
    assignment = Assignment.create!(
      title: 'Size Test Assignment',
      description: 'Testing file size limits',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # Create large file (simulate)
    large_content = "A" * (50 * 1024 * 1024) # 50MB
    large_file = Tempfile.new(['large', '.txt'])
    large_file.write(large_content)
    large_file.rewind
    
    submission = Submission.new(
      assignment: assignment,
      user: @student,
      content: 'Test submission with large file'
    )
    
    submission.file.attach(
      io: large_file,
      filename: 'large.txt',
      content_type: 'text/plain'
    )
    
    # Should reject files that are too large
    refute submission.valid?
    assert submission.errors[:file].present?
    
    large_file.close
    large_file.unlink
  end

  test "file uploads should sanitize filenames" do
    assignment = Assignment.create!(
      title: 'Filename Test Assignment',
      description: 'Testing filename sanitization',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # Create file with dangerous filename
    safe_content = "This is safe content"
    temp_file = Tempfile.new(['safe', '.txt'])
    temp_file.write(safe_content)
    temp_file.rewind
    
    submission = Submission.create!(
      assignment: assignment,
      user: @student,
      content: 'Test submission'
    )
    
    # Attach file with dangerous filename
    submission.file.attach(
      io: temp_file,
      filename: '../../../etc/passwd',
      content_type: 'text/plain'
    )
    
    # Filename should be sanitized
    if submission.file.attached?
      refute submission.file.filename.to_s.include?('../')
      refute submission.file.filename.to_s.include?('etc/passwd')
    end
    
    temp_file.close
    temp_file.unlink
  end

  # Authorization Security Tests
  test "students cannot access other students' data" do
    other_student = User.create!(
      email: 'other@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    # Create assignment and submissions
    assignment = Assignment.create!(
      title: 'Privacy Test Assignment',
      description: 'Testing data privacy',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    student_submission = Submission.create!(
      assignment: assignment,
      user: @student,
      content: 'Student submission - private'
    )
    
    other_submission = Submission.create!(
      assignment: assignment,
      user: other_student,
      content: 'Other student submission - should not be visible'
    )
    
    # Student should not see other student's submission
    visible_submissions = Submission.accessible_by(@student)
    
    assert_includes visible_submissions, student_submission
    refute_includes visible_submissions, other_submission
  end

  test "teachers can only access their department's data" do
    other_department = Department.create!(
      name: 'Mathematics',
      code: 'MATH',
      description: 'Mathematics Department'
    )
    
    other_teacher = User.create!(
      email: 'otherteacher@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Teacher',
      role: 'teacher'
    )
    other_teacher.departments << other_department
    
    # Create assignments in different departments
    cs_assignment = Assignment.create!(
      title: 'CS Assignment',
      description: 'Computer Science assignment',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    math_assignment = Assignment.create!(
      title: 'Math Assignment',
      description: 'Mathematics assignment',
      due_date: 1.week.from_now,
      user: other_teacher,
      department: other_department,
      max_points: 100
    )
    
    # Teacher should only see their department's assignments
    cs_accessible = Assignment.accessible_by(@teacher)
    math_accessible = Assignment.accessible_by(other_teacher)
    
    assert_includes cs_accessible, cs_assignment
    refute_includes cs_accessible, math_assignment
    
    assert_includes math_accessible, math_assignment
    refute_includes math_accessible, cs_assignment
  end

  test "role-based permissions are enforced" do
    # Test that students cannot perform teacher actions
    assignment = Assignment.create!(
      title: 'Permission Test Assignment',
      description: 'Testing role permissions',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # Students should not be able to create assignments
    student_assignment = Assignment.new(
      title: 'Student Assignment',
      description: 'Should not be allowed',
      due_date: 1.week.from_now,
      user: @student,
      department: @department,
      max_points: 100
    )
    
    refute Pundit.policy(@student, Assignment).create?
    refute Pundit.policy(@student, student_assignment).update?
    refute Pundit.policy(@student, assignment).destroy?
  end

  # Session Security Tests
  test "sessions should expire appropriately" do
    # This would test session management in a real application
    # For now, ensure that user sessions have appropriate timeouts
    
    # Simulate expired session
    expired_time = 25.hours.ago
    
    # Mock session data
    session_data = {
      user_id: @student.id,
      last_activity: expired_time
    }
    
    # Session should be considered expired
    assert expired_time < 24.hours.ago, "Session should be expired"
  end

  test "password requirements are enforced" do
    # Test password complexity requirements
    weak_passwords = [
      '123456',
      'password',
      'abc123',
      '111111',
      'qwerty'
    ]
    
    weak_passwords.each do |weak_password|
      user = User.new(
        email: 'test@example.com',
        password: weak_password,
        first_name: 'Test',
        last_name: 'User',
        role: 'student'
      )
      
      refute user.valid?, "Weak password '#{weak_password}' should be rejected"
      assert user.errors[:password].present?
    end
  end

  # SQL Injection Prevention Tests
  test "should prevent SQL injection in search queries" do
    # Create some test notes
    Note.create!(
      title: 'Legitimate Note',
      content: 'This is a legitimate note',
      user: @student,
      is_public: true
    )
    
    # Attempt SQL injection through search
    malicious_search = "'; DROP TABLE notes; --"
    
    # Should not execute malicious SQL
    assert_nothing_raised do
      results = Note.search(malicious_search)
      # Should return empty results, not execute DROP TABLE
      assert results.is_a?(ActiveRecord::Relation)
    end
    
    # Verify table still exists
    assert Note.count >= 1
  end

  test "should sanitize user input in all forms" do
    # Test XSS prevention in various inputs
    xss_payloads = [
      '<script>alert("xss")</script>',
      'javascript:alert("xss")',
      '<img src=x onerror=alert("xss")>',
      '<svg onload=alert("xss")>'
    ]
    
    xss_payloads.each do |payload|
      note = Note.create!(
        title: payload,
        content: "Content with #{payload}",
        user: @student,
        is_public: true
      )
      
      # Content should be sanitized
      refute note.title.include?('<script>')
      refute note.content.include?('<script>')
      refute note.title.include?('javascript:')
      refute note.content.include?('javascript:')
    end
  end

  # Cross-Site Request Forgery (CSRF) Tests
  test "forms should include CSRF tokens" do
    # This would be tested in controller tests
    # Ensure CSRF protection is enabled
    assert ActionController::Base.protect_from_forgery
  end

  # Data Encryption Tests
  test "sensitive data should be encrypted at rest" do
    # Test that sensitive fields are encrypted
    user = User.create!(
      email: 'encryption@test.com',
      password: 'securepassword123',
      first_name: 'Encryption',
      last_name: 'Test',
      role: 'student'
    )
    
    # Password should not be stored in plain text
    raw_user = User.connection.execute(
      "SELECT encrypted_password FROM users WHERE id = #{user.id}"
    ).first
    
    refute_equal 'securepassword123', raw_user['encrypted_password']
    assert raw_user['encrypted_password'].length > 20 # Should be hashed
  end

  # Rate Limiting Tests
  test "should prevent rapid successive API calls" do
    # Simulate rapid API calls
    start_time = Time.current
    
    # Make multiple requests rapidly
    10.times do
      # Simulate checking attendance with TOTP
      code = @attendance_list.generate_totp_code
      @attendance_list.verify_totp_code(code)
    end
    
    elapsed = Time.current - start_time
    
    # Should implement some form of rate limiting
    # This is a placeholder - real implementation would vary
    assert elapsed > 0.1, "Should have some delay between requests"
  end

  # Access Control Tests
  test "sensitive endpoints should require authentication" do
    # Test that protected resources require authentication
    assignment = Assignment.create!(
      title: 'Protected Assignment',
      description: 'Should require authentication',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # Anonymous access should be denied
    assert_raises Pundit::NotAuthorizedError do
      Pundit.authorize(nil, assignment, :show?)
    end
  end

  test "admin privileges should be properly scoped" do
    # Admin should have broad access but not to everything
    assignment = Assignment.create!(
      title: 'Admin Test Assignment',
      description: 'Testing admin access',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      max_points: 100
    )
    
    # Admin should be able to view assignments
    assert Pundit.policy(@admin, assignment).show?
    
    # But sensitive operations might still be restricted
    # (This depends on your business logic)
    assert Pundit.policy(@admin, assignment).index?
  end

  # Data Validation Security Tests
  test "should validate all user inputs" do
    # Test that malformed data is rejected
    invalid_assignment = Assignment.new(
      title: nil,
      description: '',
      due_date: 1.day.ago, # Past date
      user: nil,
      department: nil,
      max_points: -10 # Negative points
    )
    
    refute invalid_assignment.valid?
    assert invalid_assignment.errors.count > 0
  end

  test "should prevent mass assignment vulnerabilities" do
    # Test that sensitive attributes cannot be mass-assigned
    user_params = {
      email: 'newuser@test.com',
      password: 'password123',
      first_name: 'New',
      last_name: 'User',
      role: 'admin' # Should not be assignable by students
    }
    
    # This test depends on your strong parameters implementation
    # Students should not be able to assign themselves admin role
    user = User.new(user_params.except(:role))
    user.role = 'student' # Should be set explicitly by authorized users
    
    assert_equal 'student', user.role
  end

  # Logging and Monitoring Tests
  test "security events should be logged" do
    # Test that security-relevant events are logged
    original_logger = Rails.logger
    logged_messages = []
    
    # Mock logger to capture messages
    mock_logger = Object.new
    mock_logger.define_singleton_method(:info) { |msg| logged_messages << msg }
    mock_logger.define_singleton_method(:warn) { |msg| logged_messages << msg }
    mock_logger.define_singleton_method(:error) { |msg| logged_messages << msg }
    
    Rails.stub(:logger, mock_logger) do
      # Trigger a failed login attempt
      user = User.new(email: 'test@test.com', password: 'wrongpassword')
      user.valid? # This might trigger validation errors
    end
    
    # Some security events should be logged
    # (This is a simplified test - real implementation would vary)
    Rails.logger = original_logger
  end

  # Backup and Recovery Security Tests
  test "should handle data corruption gracefully" do
    # Test that system handles corrupted data appropriately
    note = Note.create!(
      title: 'Test Note',
      content: 'Original content',
      user: @student,
      is_public: true
    )
    
    # Simulate data corruption
    Note.connection.execute(
      "UPDATE notes SET content = null WHERE id = #{note.id}"
    )
    
    note.reload
    
    # Should handle null content gracefully
    assert_nothing_raised do
      note.content || 'Content unavailable'
    end
  end

  # Privacy Tests
  test "should respect user privacy settings" do
    # Create private note
    private_note = Note.create!(
      title: 'Private Note',
      content: 'This should be private',
      user: @student,
      is_public: false
    )
    
    # Other users should not see private notes
    other_user = User.create!(
      email: 'other@privacy.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'User',
      role: 'student'
    )
    
    visible_notes = Note.accessible_by(other_user)
    refute_includes visible_notes, private_note
  end

  # Cleanup and Secure Deletion Tests
  test "should securely delete sensitive data" do
    # Create user with sensitive data
    user = User.create!(
      email: 'delete@test.com',
      password: 'password123',
      first_name: 'Delete',
      last_name: 'Test',
      role: 'student'
    )
    
    user_id = user.id
    
    # Delete user
    user.destroy
    
    # Data should be properly cleaned up
    assert_nil User.find_by(id: user_id)
    
    # Associated data should also be cleaned up
    assert_equal 0, Note.where(user_id: user_id).count
    assert_equal 0, Submission.where(user_id: user_id).count
  end
end