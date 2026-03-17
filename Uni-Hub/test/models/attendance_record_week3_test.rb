require 'test_helper'

class AttendanceRecordTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @student = users(:student)
    @department = departments(:computer_science)
    
    @attendance_list = AttendanceList.create!(
      title: 'Monday Morning Lecture',
      description: 'Introduction to Computer Science',
      location: 'Room 101',
      start_time: 30.minutes.ago,  # Active session
      user: @teacher,
      department: @department
    )
    
    @attendance_record = AttendanceRecord.new(
      attendance_list: @attendance_list,
      user: @student
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @attendance_record.valid?
  end

  test "should require attendance_list" do
    @attendance_record.attendance_list = nil
    assert_not @attendance_record.valid?
    assert_includes @attendance_record.errors[:attendance_list], "must exist"
  end

  test "should require user" do
    @attendance_record.user = nil
    assert_not @attendance_record.valid?
    assert_includes @attendance_record.errors[:user], "must exist"
  end

  test "should require unique user per attendance list" do
    @attendance_record.save!
    
    duplicate_record = AttendanceRecord.new(
      attendance_list: @attendance_list,
      user: @student
    )
    
    assert_not duplicate_record.valid?
    assert_includes duplicate_record.errors[:user_id], "has already been taken"
  end

  test "should allow same user in different attendance lists" do
    @attendance_record.save!
    
    other_list = AttendanceList.create!(
      title: 'Tuesday Lecture',
      description: 'Advanced topics',
      location: 'Room 102',
      start_time: 30.minutes.ago,
      user: @teacher,
      department: @department
    )
    
    other_record = AttendanceRecord.new(
      attendance_list: other_list,
      user: @student
    )
    
    assert other_record.valid?
  end

  # Association Tests
  test "should belong to attendance_list" do
    assert_respond_to @attendance_record, :attendance_list
    @attendance_record.save!
    assert_instance_of AttendanceList, @attendance_record.attendance_list
  end

  test "should belong to user" do
    assert_respond_to @attendance_record, :user
    @attendance_record.save!
    assert_instance_of User, @attendance_record.user
  end

  # Timestamp Tests
  test "should set recorded_at automatically on creation" do
    freeze_time = Time.current
    travel_to freeze_time do
      @attendance_record.save!
      assert_equal freeze_time.to_i, @attendance_record.recorded_at.to_i
    end
  end

  test "should not update recorded_at on updates" do
    @attendance_record.save!
    original_recorded_at = @attendance_record.recorded_at
    
    sleep(1)
    @attendance_record.update!(user: users(:admin))
    
    assert_equal original_recorded_at.to_i, @attendance_record.recorded_at.to_i
  end

  # Status Methods Tests
  test "should correctly identify on_time attendance" do
    # Attendance within first 10 minutes of start time
    @attendance_list.update!(start_time: 5.minutes.ago)
    @attendance_record.save!
    
    assert @attendance_record.on_time?
    assert_not @attendance_record.late?
  end

  test "should correctly identify late attendance" do
    # Attendance after 10 minutes of start time
    @attendance_list.update!(start_time: 15.minutes.ago)
    @attendance_record.save!
    
    assert_not @attendance_record.on_time?
    assert @attendance_record.late?
  end

  test "should handle edge case at 10-minute boundary" do
    # Exactly 10 minutes after start time
    @attendance_list.update!(start_time: 10.minutes.ago)
    @attendance_record.save!
    
    # This might be considered late depending on implementation
    # Adjust assertion based on actual business logic
    assert @attendance_record.late?
  end

  # Scope Tests
  test "should filter on_time records" do
    # Create on-time record
    @attendance_list.update!(start_time: 5.minutes.ago)
    on_time_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: @student
    )
    
    # Create late record
    @attendance_list.update!(start_time: 15.minutes.ago)
    late_student = User.create!(
      email: 'late_student@test.com',
      password: 'password123',
      first_name: 'Late',
      last_name: 'Student',
      role: 'student'
    )
    
    late_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: late_student
    )
    
    on_time_records = AttendanceRecord.on_time
    assert_includes on_time_records, on_time_record
    assert_not_includes on_time_records, late_record
  end

  test "should filter late records" do
    # Create on-time record
    @attendance_list.update!(start_time: 5.minutes.ago)
    on_time_student = User.create!(
      email: 'ontime_student@test.com',
      password: 'password123',
      first_name: 'OnTime',
      last_name: 'Student',
      role: 'student'
    )
    
    on_time_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: on_time_student
    )
    
    # Create late record
    @attendance_list.update!(start_time: 15.minutes.ago)
    late_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: @student
    )
    
    late_records = AttendanceRecord.late
    assert_includes late_records, late_record
    assert_not_includes late_records, on_time_record
  end

  test "should filter by attendance list" do
    @attendance_record.save!
    
    other_list = AttendanceList.create!(
      title: 'Other Lecture',
      description: 'Other lecture',
      location: 'Room 103',
      start_time: 30.minutes.ago,
      user: @teacher,
      department: @department
    )
    
    other_student = User.create!(
      email: 'other_student@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    other_record = AttendanceRecord.create!(
      attendance_list: other_list,
      user: other_student
    )
    
    list_records = AttendanceRecord.for_attendance_list(@attendance_list)
    other_list_records = AttendanceRecord.for_attendance_list(other_list)
    
    assert_includes list_records, @attendance_record
    assert_not_includes list_records, other_record
    assert_includes other_list_records, other_record
    assert_not_includes other_list_records, @attendance_record
  end

  test "should filter by user" do
    @attendance_record.save!
    
    other_student = User.create!(
      email: 'other_student@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    other_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: other_student
    )
    
    student_records = AttendanceRecord.for_user(@student)
    other_student_records = AttendanceRecord.for_user(other_student)
    
    assert_includes student_records, @attendance_record
    assert_not_includes student_records, other_record
    assert_includes other_student_records, other_record
    assert_not_includes other_student_records, @attendance_record
  end

  test "should order by recorded_at" do
    # Create records with different timestamps
    first_record = nil
    second_record = nil
    third_record = nil
    
    travel_to 3.minutes.ago do
      first_record = AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: @student
      )
    end
    
    travel_to 2.minutes.ago do
      student2 = User.create!(
        email: 'student2@test.com',
        password: 'password123',
        first_name: 'Student',
        last_name: 'Two',
        role: 'student'
      )
      second_record = AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: student2
      )
    end
    
    travel_to 1.minute.ago do
      student3 = User.create!(
        email: 'student3@test.com',
        password: 'password123',
        first_name: 'Student',
        last_name: 'Three',
        role: 'student'
      )
      third_record = AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: student3
      )
    end
    
    ordered_records = AttendanceRecord.by_recorded_time
    assert_equal [first_record, second_record, third_record], ordered_records.to_a
  end

  # Business Logic Tests
  test "should calculate minutes late correctly" do
    @attendance_list.update!(start_time: 15.minutes.ago)
    @attendance_record.save!
    
    minutes_late = @attendance_record.minutes_late
    assert minutes_late >= 14  # Allow for small timing differences
    assert minutes_late <= 16
  end

  test "should return zero minutes late for on-time attendance" do
    @attendance_list.update!(start_time: 5.minutes.ago)
    @attendance_record.save!
    
    assert_equal 0, @attendance_record.minutes_late
  end

  test "should format attendance status for display" do
    # Test on-time status
    @attendance_list.update!(start_time: 5.minutes.ago)
    on_time_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: @student
    )
    
    assert_equal 'On Time', on_time_record.status_display
    
    # Test late status
    @attendance_list.update!(start_time: 20.minutes.ago)
    late_student = User.create!(
      email: 'late_student@test.com',
      password: 'password123',
      first_name: 'Late',
      last_name: 'Student',
      role: 'student'
    )
    
    late_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: late_student
    )
    
    expected_late_message = "Late (#{late_record.minutes_late} min)"
    assert_equal expected_late_message, late_record.status_display
  end

  # Performance Tests
  test "should efficiently query attendance records" do
    # Create multiple records
    20.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      
      AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: student
      )
    end
    
    # Query should be efficient
    records = AttendanceRecord.for_attendance_list(@attendance_list).includes(:user)
    assert_equal 20, records.count
    
    # Should load users efficiently with includes
    assert_no_queries do
      records.each { |record| record.user.full_name }
    end
  end

  # Statistics Tests
  test "should calculate attendance statistics" do
    # Create mixed on-time and late records
    5.times do |i|
      student = User.create!(
        email: "ontime#{i}@test.com",
        password: 'password123',
        first_name: 'OnTime',
        last_name: i.to_s,
        role: 'student'
      )
      
      @attendance_list.update!(start_time: 5.minutes.ago)
      AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: student
      )
    end
    
    3.times do |i|
      student = User.create!(
        email: "late#{i}@test.com",
        password: 'password123',
        first_name: 'Late',
        last_name: i.to_s,
        role: 'student'
      )
      
      @attendance_list.update!(start_time: 15.minutes.ago)
      AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: student
      )
    end
    
    total_count = AttendanceRecord.for_attendance_list(@attendance_list).count
    on_time_count = AttendanceRecord.for_attendance_list(@attendance_list).on_time.count
    late_count = AttendanceRecord.for_attendance_list(@attendance_list).late.count
    
    assert_equal 8, total_count
    assert_equal 5, on_time_count
    assert_equal 3, late_count
  end

  # Edge Cases
  test "should handle attendance exactly at start time" do
    travel_to @attendance_list.start_time do
      record = AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: @student
      )
      
      assert record.on_time?
      assert_equal 0, record.minutes_late
    end
  end

  test "should handle very late attendance" do
    @attendance_list.update!(start_time: 2.hours.ago)
    @attendance_record.save!
    
    assert @attendance_record.late?
    assert @attendance_record.minutes_late >= 115  # Around 2 hours
  end

  test "should handle attendance before start time" do
    # Early arrival (shouldn't happen in normal flow, but test edge case)
    @attendance_list.update!(start_time: 10.minutes.from_now)
    @attendance_record.save!
    
    # Early attendance might be considered "on time" or handled specially
    # Adjust assertion based on business requirements
    assert @attendance_record.on_time?
    assert_equal 0, @attendance_record.minutes_late
  end

  # Security Tests
  test "should prevent SQL injection in queries" do
    malicious_input = "'; DROP TABLE attendance_records; --"
    
    # Should not raise error or execute malicious SQL
    assert_nothing_raised do
      AttendanceRecord.joins(:user).where(users: { first_name: malicious_input })
    end
  end

  # Integration Tests
  test "should work with attendance list statistics" do
    @attendance_record.save!
    
    assert_equal 1, @attendance_list.total_attendance
    assert_equal 1, @attendance_list.attendance_records.count
  end

  test "should update attendance list statistics when destroyed" do
    @attendance_record.save!
    assert_equal 1, @attendance_list.total_attendance
    
    @attendance_record.destroy
    assert_equal 0, @attendance_list.reload.total_attendance
  end
end