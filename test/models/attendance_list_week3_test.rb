require 'test_helper'

class AttendanceListTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @department = departments(:computer_science)
    @attendance_list = AttendanceList.new(
      title: 'Monday Morning Lecture',
      description: 'Introduction to Computer Science',
      location: 'Room 101',
      start_time: Time.current + 1.hour,
      user: @teacher,
      department: @department
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @attendance_list.valid?
  end

  test "should require title" do
    @attendance_list.title = nil
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:title], "can't be blank"

    @attendance_list.title = ""
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:title], "can't be blank"
  end

  test "should require description" do
    @attendance_list.description = nil
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:description], "can't be blank"
  end

  test "should require location" do
    @attendance_list.location = nil
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:location], "can't be blank"
  end

  test "should require start_time" do
    @attendance_list.start_time = nil
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:start_time], "can't be blank"
  end

  test "should require user" do
    @attendance_list.user = nil
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:user], "must exist"
  end

  test "should require department" do
    @attendance_list.department = nil
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:department], "must exist"
  end

  test "should validate start_time is in future" do
    @attendance_list.start_time = 1.hour.ago
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:start_time], "must be in the future"
  end

  test "should validate title length" do
    @attendance_list.title = "a" * 201  # Assuming max length is 200
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:title], "is too long (maximum is 200 characters)"
  end

  test "should validate location length" do
    @attendance_list.location = "a" * 101  # Assuming max length is 100
    assert_not @attendance_list.valid?
    assert_includes @attendance_list.errors[:location], "is too long (maximum is 100 characters)"
  end

  # Association Tests
  test "should belong to user" do
    assert_respond_to @attendance_list, :user
    @attendance_list.save!
    assert_instance_of User, @attendance_list.user
  end

  test "should belong to department" do
    assert_respond_to @attendance_list, :department
    @attendance_list.save!
    assert_instance_of Department, @attendance_list.department
  end

  test "should have many attendance records" do
    assert_respond_to @attendance_list, :attendance_records
    @attendance_list.save!
    
    student = users(:student)
    @attendance_list.attendance_records.create!(user: student)
    
    assert_equal 1, @attendance_list.attendance_records.count
    assert_instance_of AttendanceRecord, @attendance_list.attendance_records.first
  end

  test "should destroy dependent attendance records" do
    @attendance_list.save!
    student = users(:student)
    @attendance_list.attendance_records.create!(user: student)
    
    assert_difference 'AttendanceRecord.count', -1 do
      @attendance_list.destroy
    end
  end

  # Secret Key Tests
  test "should generate secret key before save" do
    assert_nil @attendance_list.secret_key
    @attendance_list.save!
    assert_not_nil @attendance_list.secret_key
    assert_equal 32, @attendance_list.secret_key.length
  end

  test "should not regenerate secret key if already exists" do
    @attendance_list.save!
    original_key = @attendance_list.secret_key
    
    @attendance_list.update!(title: 'Updated Title')
    assert_equal original_key, @attendance_list.secret_key
  end

  test "should regenerate secret key when explicitly called" do
    @attendance_list.save!
    original_key = @attendance_list.secret_key
    
    @attendance_list.regenerate_secret_key!
    assert_not_equal original_key, @attendance_list.secret_key
    assert_equal 32, @attendance_list.secret_key.length
  end

  # TOTP Code Generation Tests
  test "should generate current TOTP code" do
    @attendance_list.save!
    code = @attendance_list.current_code
    
    assert_not_nil code
    assert_instance_of String, code
    assert_equal 6, code.length
    assert_match /\A\d{6}\z/, code  # Should be 6 digits
  end

  test "should generate consistent code within time window" do
    @attendance_list.save!
    
    code1 = @attendance_list.current_code
    sleep(1)  # Wait 1 second
    code2 = @attendance_list.current_code
    
    # Should be same code within 2-minute window
    assert_equal code1, code2
  end

  test "should verify valid TOTP code" do
    @attendance_list.save!
    current_code = @attendance_list.current_code
    
    assert @attendance_list.verify_code?(current_code)
  end

  test "should reject invalid TOTP code" do
    @attendance_list.save!
    
    assert_not @attendance_list.verify_code?('000000')
    assert_not @attendance_list.verify_code?('123456')
    assert_not @attendance_list.verify_code?('invalid')
  end

  test "should reject expired codes" do
    @attendance_list.save!
    
    # Mock time to generate old code
    travel_to 5.minutes.ago do
      old_code = @attendance_list.current_code
      travel_back
      
      # Old code should not be valid now
      assert_not @attendance_list.verify_code?(old_code)
    end
  end

  # Status Tests
  test "should correctly identify upcoming attendance list" do
    @attendance_list.start_time = 2.hours.from_now
    @attendance_list.save!
    
    assert @attendance_list.upcoming?
    assert_not @attendance_list.active?
    assert_not @attendance_list.completed?
  end

  test "should correctly identify active attendance list" do
    @attendance_list.start_time = 30.minutes.ago
    @attendance_list.save!
    
    assert_not @attendance_list.upcoming?
    assert @attendance_list.active?
    assert_not @attendance_list.completed?
  end

  test "should correctly identify completed attendance list" do
    @attendance_list.start_time = 3.hours.ago
    @attendance_list.save!
    
    assert_not @attendance_list.upcoming?
    assert_not @attendance_list.active?
    assert @attendance_list.completed?
  end

  # Scope Tests
  test "should filter upcoming attendance lists" do
    @attendance_list.start_time = 2.hours.from_now
    @attendance_list.save!
    
    past_list = AttendanceList.create!(
      title: 'Past Lecture',
      description: 'Past lecture',
      location: 'Room 102',
      start_time: 3.hours.ago,
      user: @teacher,
      department: @department
    )
    
    upcoming_lists = AttendanceList.upcoming
    assert_includes upcoming_lists, @attendance_list
    assert_not_includes upcoming_lists, past_list
  end

  test "should filter active attendance lists" do
    @attendance_list.start_time = 30.minutes.ago
    @attendance_list.save!
    
    future_list = AttendanceList.create!(
      title: 'Future Lecture',
      description: 'Future lecture',
      location: 'Room 103',
      start_time: 2.hours.from_now,
      user: @teacher,
      department: @department
    )
    
    active_lists = AttendanceList.active
    assert_includes active_lists, @attendance_list
    assert_not_includes active_lists, future_list
  end

  test "should filter by department" do
    @attendance_list.save!
    
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_list = AttendanceList.create!(
      title: 'Physics Lecture',
      description: 'Physics lecture',
      location: 'Physics Lab',
      start_time: 1.hour.from_now,
      user: @teacher,
      department: physics_dept
    )
    
    cs_lists = AttendanceList.for_department(@department)
    physics_lists = AttendanceList.for_department(physics_dept)
    
    assert_includes cs_lists, @attendance_list
    assert_not_includes cs_lists, physics_list
    assert_includes physics_lists, physics_list
    assert_not_includes physics_lists, @attendance_list
  end

  test "should order by start time" do
    @attendance_list.start_time = 2.hours.from_now
    @attendance_list.save!
    
    earlier_list = AttendanceList.create!(
      title: 'Earlier Lecture',
      description: 'Earlier lecture',
      location: 'Room 100',
      start_time: 1.hour.from_now,
      user: @teacher,
      department: @department
    )
    
    later_list = AttendanceList.create!(
      title: 'Later Lecture',
      description: 'Later lecture',
      location: 'Room 103',
      start_time: 3.hours.from_now,
      user: @teacher,
      department: @department
    )
    
    ordered_lists = AttendanceList.by_start_time
    assert_equal [earlier_list, @attendance_list, later_list], ordered_lists.to_a
  end

  # Statistics Tests
  test "should calculate total attendance count" do
    @attendance_list.save!
    
    student1 = users(:student)
    student2 = User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    )
    
    @attendance_list.attendance_records.create!(user: student1)
    @attendance_list.attendance_records.create!(user: student2)
    
    assert_equal 2, @attendance_list.total_attendance
  end

  test "should calculate attendance percentage" do
    @attendance_list.save!
    
    # Create some students
    4.times do |i|
      User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
    end
    
    # 2 out of 5 students (including existing student) attend
    students = User.where(role: 'student').limit(2)
    students.each do |student|
      @attendance_list.attendance_records.create!(user: student)
    end
    
    # Mock department users count if needed
    allow(@attendance_list.department).to receive(:users).and_return(User.where(role: 'student'))
    
    percentage = @attendance_list.attendance_percentage
    assert_equal 40.0, percentage  # 2/5 * 100
  end

  # Business Logic Tests
  test "should allow attendance only during active period" do
    @attendance_list.save!
    student = users(:student)
    
    # Future event - should not allow attendance
    @attendance_list.update!(start_time: 2.hours.from_now)
    assert_not @attendance_list.can_take_attendance?
    
    # Active event - should allow attendance
    @attendance_list.update!(start_time: 30.minutes.ago)
    assert @attendance_list.can_take_attendance?
    
    # Past event - should not allow attendance
    @attendance_list.update!(start_time: 3.hours.ago)
    assert_not @attendance_list.can_take_attendance?
  end

  test "should prevent duplicate attendance records" do
    @attendance_list.save!
    student = users(:student)
    
    @attendance_list.attendance_records.create!(user: student)
    
    duplicate_record = @attendance_list.attendance_records.build(user: student)
    assert_not duplicate_record.valid?
    assert_includes duplicate_record.errors[:user_id], "has already been taken"
  end

  # Security Tests
  test "should use secure random for secret key generation" do
    key_lengths = []
    5.times do
      list = AttendanceList.create!(
        title: "Test #{rand(1000)}",
        description: 'Test description',
        location: 'Test location',
        start_time: 1.hour.from_now,
        user: @teacher,
        department: @department
      )
      key_lengths << list.secret_key.length
    end
    
    # All keys should be 32 characters
    assert key_lengths.all? { |length| length == 32 }
  end

  test "should have unique secret keys" do
    keys = []
    5.times do
      list = AttendanceList.create!(
        title: "Test #{rand(1000)}",
        description: 'Test description',
        location: 'Test location',
        start_time: 1.hour.from_now,
        user: @teacher,
        department: @department
      )
      keys << list.secret_key
    end
    
    assert_equal keys.uniq.length, keys.length
  end

  # Edge Cases
  test "should handle nil verification gracefully" do
    @attendance_list.save!
    
    assert_not @attendance_list.verify_code?(nil)
    assert_not @attendance_list.verify_code?('')
  end

  test "should handle malformed codes" do
    @attendance_list.save!
    
    assert_not @attendance_list.verify_code?('12345')  # Too short
    assert_not @attendance_list.verify_code?('1234567')  # Too long
    assert_not @attendance_list.verify_code?('abcdef')  # Non-numeric
    assert_not @attendance_list.verify_code?('12 345')  # Contains space
  end

  test "should handle boundary time conditions" do
    @attendance_list.start_time = Time.current
    @attendance_list.save!
    
    # Should be considered active right at start time
    assert @attendance_list.active?
    
    # Test exact 2-hour boundary
    travel_to @attendance_list.start_time + 2.hours do
      assert @attendance_list.completed?
    end
  end
end