require 'test_helper'

class ScheduleTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @student = users(:student)
    @department = departments(:computer_science)
    
    @schedule = Schedule.new(
      title: 'Advanced Programming Lecture',
      description: 'Weekly programming concepts discussion',
      location: 'Computer Lab 1',
      start_time: Time.current + 1.day,
      end_time: Time.current + 1.day + 2.hours,
      user: @teacher,
      department: @department,
      max_participants: 30,
      schedule_type: 'class'
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @schedule.valid?
  end

  test "should require title" do
    @schedule.title = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:title], "can't be blank"

    @schedule.title = ""
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:title], "can't be blank"
  end

  test "should require description" do
    @schedule.description = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:description], "can't be blank"
  end

  test "should require location" do
    @schedule.location = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:location], "can't be blank"
  end

  test "should require start_time" do
    @schedule.start_time = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:start_time], "can't be blank"
  end

  test "should require end_time" do
    @schedule.end_time = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:end_time], "can't be blank"
  end

  test "should require user" do
    @schedule.user = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:user], "must exist"
  end

  test "should require department" do
    @schedule.department = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:department], "must exist"
  end

  test "should validate end_time is after start_time" do
    @schedule.end_time = @schedule.start_time - 1.hour
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:end_time], "must be after start time"
  end

  test "should not allow end_time equal to start_time" do
    @schedule.end_time = @schedule.start_time
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:end_time], "must be after start time"
  end

  test "should validate start_time is in future" do
    @schedule.start_time = 1.hour.ago
    @schedule.end_time = 30.minutes.ago
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:start_time], "must be in the future"
  end

  test "should validate max_participants is positive" do
    @schedule.max_participants = 0
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:max_participants], "must be greater than 0"

    @schedule.max_participants = -5
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:max_participants], "must be greater than 0"
  end

  test "should validate schedule_type inclusion" do
    @schedule.schedule_type = 'invalid_type'
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:schedule_type], "is not included in the list"

    valid_types = ['class', 'meeting', 'exam', 'office_hours', 'study_group']
    valid_types.each do |type|
      @schedule.schedule_type = type
      assert @schedule.valid?, "#{type} should be a valid schedule type"
    end
  end

  test "should validate title length" do
    @schedule.title = "a" * 201  # Assuming max length is 200
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:title], "is too long (maximum is 200 characters)"
  end

  test "should validate location length" do
    @schedule.location = "a" * 101  # Assuming max length is 100
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:location], "is too long (maximum is 100 characters)"
  end

  # Association Tests
  test "should belong to user" do
    assert_respond_to @schedule, :user
    @schedule.save!
    assert_instance_of User, @schedule.user
  end

  test "should belong to department" do
    assert_respond_to @schedule, :department
    @schedule.save!
    assert_instance_of Department, @schedule.department
  end

  test "should have many schedule participants" do
    assert_respond_to @schedule, :schedule_participants
    @schedule.save!
    
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    assert_equal 1, @schedule.schedule_participants.count
    assert_instance_of ScheduleParticipant, @schedule.schedule_participants.first
  end

  test "should have many participants through schedule_participants" do
    assert_respond_to @schedule, :participants
    @schedule.save!
    
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    assert_equal 1, @schedule.participants.count
    assert_instance_of User, @schedule.participants.first
    assert_equal @student, @schedule.participants.first
  end

  test "should destroy dependent schedule participants" do
    @schedule.save!
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    assert_difference 'ScheduleParticipant.count', -1 do
      @schedule.destroy
    end
  end

  # Time Conflict Validation Tests
  test "should detect overlapping schedules for same user" do
    @schedule.save!
    
    # Create overlapping schedule
    overlapping_schedule = Schedule.new(
      title: 'Conflicting Meeting',
      description: 'This conflicts with existing schedule',
      location: 'Room 102',
      start_time: @schedule.start_time + 30.minutes,
      end_time: @schedule.end_time + 30.minutes,
      user: @teacher,  # Same user
      department: @department,
      max_participants: 20,
      schedule_type: 'meeting'
    )
    
    assert_not overlapping_schedule.valid?
    assert_includes overlapping_schedule.errors[:start_time], "conflicts with existing schedule"
  end

  test "should allow non-overlapping schedules for same user" do
    @schedule.save!
    
    # Create non-overlapping schedule
    non_overlapping_schedule = Schedule.new(
      title: 'Later Meeting',
      description: 'This does not conflict',
      location: 'Room 102',
      start_time: @schedule.end_time + 1.hour,
      end_time: @schedule.end_time + 3.hours,
      user: @teacher,  # Same user
      department: @department,
      max_participants: 20,
      schedule_type: 'meeting'
    )
    
    assert non_overlapping_schedule.valid?
  end

  test "should allow overlapping schedules for different users" do
    @schedule.save!
    
    other_teacher = User.create!(
      email: 'other_teacher@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    # Create overlapping schedule with different user
    overlapping_schedule = Schedule.new(
      title: 'Parallel Class',
      description: 'Different teacher, same time',
      location: 'Room 102',
      start_time: @schedule.start_time + 30.minutes,
      end_time: @schedule.end_time + 30.minutes,
      user: other_teacher,  # Different user
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    assert overlapping_schedule.valid?
  end

  test "should detect edge case time conflicts" do
    @schedule.save!
    
    # Start exactly when other ends (should be valid)
    adjacent_schedule = Schedule.new(
      title: 'Adjacent Meeting',
      description: 'Starts when other ends',
      location: 'Room 102',
      start_time: @schedule.end_time,
      end_time: @schedule.end_time + 2.hours,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'meeting'
    )
    
    assert adjacent_schedule.valid?
    
    # End exactly when other starts (should be valid)
    preceding_schedule = Schedule.new(
      title: 'Preceding Meeting',
      description: 'Ends when other starts',
      location: 'Room 102',
      start_time: @schedule.start_time - 2.hours,
      end_time: @schedule.start_time,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'meeting'
    )
    
    assert preceding_schedule.valid?
  end

  # Status Methods Tests
  test "should correctly identify upcoming schedule" do
    @schedule.start_time = 2.hours.from_now
    @schedule.end_time = 4.hours.from_now
    @schedule.save!
    
    assert @schedule.upcoming?
    assert_not @schedule.ongoing?
    assert_not @schedule.completed?
  end

  test "should correctly identify ongoing schedule" do
    @schedule.start_time = 30.minutes.ago
    @schedule.end_time = 1.hour.from_now
    @schedule.save!
    
    assert_not @schedule.upcoming?
    assert @schedule.ongoing?
    assert_not @schedule.completed?
  end

  test "should correctly identify completed schedule" do
    @schedule.start_time = 3.hours.ago
    @schedule.end_time = 1.hour.ago
    @schedule.save!
    
    assert_not @schedule.upcoming?
    assert_not @schedule.ongoing?
    assert @schedule.completed?
  end

  # Participant Management Tests
  test "should calculate current enrollment count" do
    @schedule.save!
    
    # Add enrolled participants
    3.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      @schedule.schedule_participants.create!(user: student, status: 'enrolled')
    end
    
    # Add waitlisted participant (shouldn't count)
    waitlisted_student = User.create!(
      email: 'waitlisted@test.com',
      password: 'password123',
      first_name: 'Waitlisted',
      last_name: 'Student',
      role: 'student'
    )
    @schedule.schedule_participants.create!(user: waitlisted_student, status: 'waitlisted')
    
    assert_equal 3, @schedule.current_enrollment
  end

  test "should determine if schedule is full" do
    @schedule.max_participants = 2
    @schedule.save!
    
    assert_not @schedule.full?
    
    # Add participants up to max
    2.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      @schedule.schedule_participants.create!(user: student, status: 'enrolled')
    end
    
    assert @schedule.full?
  end

  test "should calculate available spots" do
    @schedule.max_participants = 5
    @schedule.save!
    
    assert_equal 5, @schedule.available_spots
    
    # Add 2 enrolled participants
    2.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      @schedule.schedule_participants.create!(user: student, status: 'enrolled')
    end
    
    assert_equal 3, @schedule.available_spots
  end

  test "should determine if user can enroll" do
    @schedule.save!
    
    # User not enrolled - should be able to enroll
    assert @schedule.can_enroll?(@student)
    
    # User already enrolled - should not be able to enroll again
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    assert_not @schedule.can_enroll?(@student)
    
    # Schedule full - new user should not be able to enroll
    @schedule.max_participants = 1
    @schedule.save!
    
    new_student = User.create!(
      email: 'newstudent@test.com',
      password: 'password123',
      first_name: 'New',
      last_name: 'Student',
      role: 'student'
    )
    
    assert_not @schedule.can_enroll?(new_student)
  end

  # Scope Tests
  test "should filter upcoming schedules" do
    @schedule.start_time = 2.hours.from_now
    @schedule.end_time = 4.hours.from_now
    @schedule.save!
    
    past_schedule = Schedule.create!(
      title: 'Past Class',
      description: 'This class is over',
      location: 'Room 102',
      start_time: 3.hours.ago,
      end_time: 1.hour.ago,
      user: @teacher,
      department: @department,
      max_participants: 30,
      schedule_type: 'class'
    )
    
    upcoming_schedules = Schedule.upcoming
    assert_includes upcoming_schedules, @schedule
    assert_not_includes upcoming_schedules, past_schedule
  end

  test "should filter ongoing schedules" do
    @schedule.start_time = 30.minutes.ago
    @schedule.end_time = 1.hour.from_now
    @schedule.save!
    
    future_schedule = Schedule.create!(
      title: 'Future Class',
      description: 'This class is later',
      location: 'Room 103',
      start_time: 2.hours.from_now,
      end_time: 4.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 30,
      schedule_type: 'class'
    )
    
    ongoing_schedules = Schedule.ongoing
    assert_includes ongoing_schedules, @schedule
    assert_not_includes ongoing_schedules, future_schedule
  end

  test "should filter by department" do
    @schedule.save!
    
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_schedule = Schedule.create!(
      title: 'Physics Lab',
      description: 'Laboratory session',
      location: 'Physics Lab',
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 3.hours,
      user: @teacher,
      department: physics_dept,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    cs_schedules = Schedule.for_department(@department)
    physics_schedules = Schedule.for_department(physics_dept)
    
    assert_includes cs_schedules, @schedule
    assert_not_includes cs_schedules, physics_schedule
    assert_includes physics_schedules, physics_schedule
    assert_not_includes physics_schedules, @schedule
  end

  test "should filter by schedule type" do
    @schedule.save!
    
    meeting_schedule = Schedule.create!(
      title: 'Faculty Meeting',
      description: 'Monthly faculty meeting',
      location: 'Conference Room',
      start_time: 2.days.from_now,
      end_time: 2.days.from_now + 1.hour,
      user: @teacher,
      department: @department,
      max_participants: 10,
      schedule_type: 'meeting'
    )
    
    class_schedules = Schedule.of_type('class')
    meeting_schedules = Schedule.of_type('meeting')
    
    assert_includes class_schedules, @schedule
    assert_not_includes class_schedules, meeting_schedule
    assert_includes meeting_schedules, meeting_schedule
    assert_not_includes meeting_schedules, @schedule
  end

  test "should order by start time" do
    @schedule.start_time = 2.hours.from_now
    @schedule.end_time = 4.hours.from_now
    @schedule.save!
    
    earlier_schedule = Schedule.create!(
      title: 'Earlier Class',
      description: 'This comes first',
      location: 'Room 100',
      start_time: 1.hour.from_now,
      end_time: 3.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 25,
      schedule_type: 'class'
    )
    
    later_schedule = Schedule.create!(
      title: 'Later Class',
      description: 'This comes last',
      location: 'Room 103',
      start_time: 3.hours.from_now,
      end_time: 5.hours.from_now,
      user: @teacher,
      department: @department,
      max_participants: 35,
      schedule_type: 'class'
    )
    
    ordered_schedules = Schedule.by_start_time
    assert_equal [earlier_schedule, @schedule, later_schedule], ordered_schedules.to_a
  end

  # Reminder System Tests
  test "should determine if reminder should be sent" do
    @schedule.save!
    
    # Schedule starting in 25 hours - reminder should be sent (24h before)
    @schedule.update!(start_time: 25.hours.from_now)
    assert @schedule.should_send_reminder?
    
    # Schedule starting in 23 hours - reminder already should have been sent
    @schedule.update!(start_time: 23.hours.from_now)
    assert_not @schedule.should_send_reminder?
    
    # Schedule starting in 30 minutes - too late for reminder
    @schedule.update!(start_time: 30.minutes.from_now)
    assert_not @schedule.should_send_reminder?
  end

  test "should mark reminder as sent" do
    @schedule.save!
    
    assert_nil @schedule.reminder_sent_at
    
    @schedule.mark_reminder_sent!
    assert_not_nil @schedule.reminder_sent_at
    assert_in_delta Time.current, @schedule.reminder_sent_at, 1.second
  end

  test "should not send duplicate reminders" do
    @schedule.start_time = 25.hours.from_now
    @schedule.save!
    
    assert @schedule.should_send_reminder?
    
    @schedule.mark_reminder_sent!
    assert_not @schedule.should_send_reminder?
  end

  # Business Logic Tests
  test "should calculate duration in hours" do
    @schedule.start_time = Time.current + 1.day
    @schedule.end_time = Time.current + 1.day + 2.5.hours
    @schedule.save!
    
    assert_equal 2.5, @schedule.duration_hours
  end

  test "should format time range for display" do
    start_time = Time.parse('2024-03-15 10:00:00')
    end_time = Time.parse('2024-03-15 12:30:00')
    
    @schedule.start_time = start_time
    @schedule.end_time = end_time
    @schedule.save!
    
    expected_format = "#{start_time.strftime('%B %d, %Y at %I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
    assert_equal expected_format, @schedule.time_range_display
  end

  # Edge Cases
  test "should handle boundary conditions for status" do
    # Right at start time
    @schedule.start_time = Time.current
    @schedule.end_time = 2.hours.from_now
    @schedule.save!
    
    assert @schedule.ongoing?
    
    # Right at end time
    @schedule.start_time = 2.hours.ago
    @schedule.end_time = Time.current
    @schedule.save!
    
    assert @schedule.completed?
  end

  test "should handle very long schedules" do
    @schedule.start_time = 1.day.from_now
    @schedule.end_time = 2.days.from_now  # 24-hour schedule
    @schedule.save!
    
    assert @schedule.valid?
    assert_equal 24.0, @schedule.duration_hours
  end

  test "should handle schedules with zero max participants" do
    @schedule.max_participants = nil
    assert_not @schedule.valid?
    
    @schedule.max_participants = 0
    assert_not @schedule.valid?
  end

  # Performance Tests
  test "should efficiently load participants with associations" do
    @schedule.save!
    
    # Create multiple participants
    10.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      @schedule.schedule_participants.create!(user: student, status: 'enrolled')
    end
    
    # Query should be efficient with includes
    schedule_with_participants = Schedule.includes(schedule_participants: :user).find(@schedule.id)
    
    assert_no_queries do
      schedule_with_participants.schedule_participants.each do |participant|
        participant.user.full_name
      end
    end
  end
end