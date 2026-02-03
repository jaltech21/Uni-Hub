require 'test_helper'

class ScheduleParticipantTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @student = users(:student)
    @department = departments(:computer_science)
    
    @schedule = Schedule.create!(
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
    
    @schedule_participant = ScheduleParticipant.new(
      schedule: @schedule,
      user: @student,
      status: 'enrolled'
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @schedule_participant.valid?
  end

  test "should require schedule" do
    @schedule_participant.schedule = nil
    assert_not @schedule_participant.valid?
    assert_includes @schedule_participant.errors[:schedule], "must exist"
  end

  test "should require user" do
    @schedule_participant.user = nil
    assert_not @schedule_participant.valid?
    assert_includes @schedule_participant.errors[:user], "must exist"
  end

  test "should require status" do
    @schedule_participant.status = nil
    assert_not @schedule_participant.valid?
    assert_includes @schedule_participant.errors[:status], "can't be blank"

    @schedule_participant.status = ""
    assert_not @schedule_participant.valid?
    assert_includes @schedule_participant.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    @schedule_participant.status = 'invalid_status'
    assert_not @schedule_participant.valid?
    assert_includes @schedule_participant.errors[:status], "is not included in the list"

    valid_statuses = ['enrolled', 'waitlisted', 'dropped', 'completed']
    valid_statuses.each do |status|
      @schedule_participant.status = status
      assert @schedule_participant.valid?, "#{status} should be a valid status"
    end
  end

  test "should require unique user per schedule" do
    @schedule_participant.save!
    
    duplicate_participant = ScheduleParticipant.new(
      schedule: @schedule,
      user: @student,
      status: 'waitlisted'
    )
    
    assert_not duplicate_participant.valid?
    assert_includes duplicate_participant.errors[:user_id], "has already been taken"
  end

  test "should allow same user in different schedules" do
    @schedule_participant.save!
    
    other_schedule = Schedule.create!(
      title: 'Database Systems',
      description: 'Database design and implementation',
      location: 'Room 102',
      start_time: Time.current + 2.days,
      end_time: Time.current + 2.days + 2.hours,
      user: @teacher,
      department: @department,
      max_participants: 25,
      schedule_type: 'class'
    )
    
    other_participant = ScheduleParticipant.new(
      schedule: other_schedule,
      user: @student,
      status: 'enrolled'
    )
    
    assert other_participant.valid?
  end

  # Association Tests
  test "should belong to schedule" do
    assert_respond_to @schedule_participant, :schedule
    @schedule_participant.save!
    assert_instance_of Schedule, @schedule_participant.schedule
  end

  test "should belong to user" do
    assert_respond_to @schedule_participant, :user
    @schedule_participant.save!
    assert_instance_of User, @schedule_participant.user
  end

  # Timestamp Tests
  test "should set enrolled_at automatically for enrolled status" do
    freeze_time = Time.current
    travel_to freeze_time do
      @schedule_participant.status = 'enrolled'
      @schedule_participant.save!
      assert_equal freeze_time.to_i, @schedule_participant.enrolled_at.to_i
    end
  end

  test "should not set enrolled_at for non-enrolled status" do
    @schedule_participant.status = 'waitlisted'
    @schedule_participant.save!
    assert_nil @schedule_participant.enrolled_at
  end

  test "should set dropped_at when status changes to dropped" do
    @schedule_participant.save!
    
    freeze_time = Time.current + 1.day
    travel_to freeze_time do
      @schedule_participant.update!(status: 'dropped')
      assert_equal freeze_time.to_i, @schedule_participant.dropped_at.to_i
    end
  end

  test "should set completed_at when status changes to completed" do
    @schedule_participant.save!
    
    freeze_time = Time.current + 1.week
    travel_to freeze_time do
      @schedule_participant.update!(status: 'completed')
      assert_equal freeze_time.to_i, @schedule_participant.completed_at.to_i
    end
  end

  # Status Query Methods Tests
  test "should correctly identify enrolled participants" do
    @schedule_participant.status = 'enrolled'
    @schedule_participant.save!
    
    assert @schedule_participant.enrolled?
    assert_not @schedule_participant.waitlisted?
    assert_not @schedule_participant.dropped?
    assert_not @schedule_participant.completed?
  end

  test "should correctly identify waitlisted participants" do
    @schedule_participant.status = 'waitlisted'
    @schedule_participant.save!
    
    assert_not @schedule_participant.enrolled?
    assert @schedule_participant.waitlisted?
    assert_not @schedule_participant.dropped?
    assert_not @schedule_participant.completed?
  end

  test "should correctly identify dropped participants" do
    @schedule_participant.status = 'dropped'
    @schedule_participant.save!
    
    assert_not @schedule_participant.enrolled?
    assert_not @schedule_participant.waitlisted?
    assert @schedule_participant.dropped?
    assert_not @schedule_participant.completed?
  end

  test "should correctly identify completed participants" do
    @schedule_participant.status = 'completed'
    @schedule_participant.save!
    
    assert_not @schedule_participant.enrolled?
    assert_not @schedule_participant.waitlisted?
    assert_not @schedule_participant.dropped?
    assert @schedule_participant.completed?
  end

  # Scope Tests
  test "should filter enrolled participants" do
    @schedule_participant.status = 'enrolled'
    @schedule_participant.save!
    
    waitlisted_student = User.create!(
      email: 'waitlisted@test.com',
      password: 'password123',
      first_name: 'Waitlisted',
      last_name: 'Student',
      role: 'student'
    )
    
    waitlisted_participant = ScheduleParticipant.create!(
      schedule: @schedule,
      user: waitlisted_student,
      status: 'waitlisted'
    )
    
    enrolled_participants = ScheduleParticipant.enrolled
    assert_includes enrolled_participants, @schedule_participant
    assert_not_includes enrolled_participants, waitlisted_participant
  end

  test "should filter waitlisted participants" do
    @schedule_participant.status = 'waitlisted'
    @schedule_participant.save!
    
    enrolled_student = User.create!(
      email: 'enrolled@test.com',
      password: 'password123',
      first_name: 'Enrolled',
      last_name: 'Student',
      role: 'student'
    )
    
    enrolled_participant = ScheduleParticipant.create!(
      schedule: @schedule,
      user: enrolled_student,
      status: 'enrolled'
    )
    
    waitlisted_participants = ScheduleParticipant.waitlisted
    assert_includes waitlisted_participants, @schedule_participant
    assert_not_includes waitlisted_participants, enrolled_participant
  end

  test "should filter by schedule" do
    @schedule_participant.save!
    
    other_schedule = Schedule.create!(
      title: 'Other Class',
      description: 'Different class',
      location: 'Room 103',
      start_time: Time.current + 3.days,
      end_time: Time.current + 3.days + 1.hour,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    other_student = User.create!(
      email: 'other@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    other_participant = ScheduleParticipant.create!(
      schedule: other_schedule,
      user: other_student,
      status: 'enrolled'
    )
    
    schedule_participants = ScheduleParticipant.for_schedule(@schedule)
    other_schedule_participants = ScheduleParticipant.for_schedule(other_schedule)
    
    assert_includes schedule_participants, @schedule_participant
    assert_not_includes schedule_participants, other_participant
    assert_includes other_schedule_participants, other_participant
    assert_not_includes other_schedule_participants, @schedule_participant
  end

  test "should filter by user" do
    @schedule_participant.save!
    
    other_student = User.create!(
      email: 'other@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    other_participant = ScheduleParticipant.create!(
      schedule: @schedule,
      user: other_student,
      status: 'enrolled'
    )
    
    student_participants = ScheduleParticipant.for_user(@student)
    other_student_participants = ScheduleParticipant.for_user(other_student)
    
    assert_includes student_participants, @schedule_participant
    assert_not_includes student_participants, other_participant
    assert_includes other_student_participants, other_participant
    assert_not_includes other_student_participants, @schedule_participant
  end

  test "should order by enrolled_at" do
    # Create participants with different enrollment times
    participants = []
    
    3.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      
      travel_to (i + 1).hours.ago do
        participant = ScheduleParticipant.create!(
          schedule: @schedule,
          user: student,
          status: 'enrolled'
        )
        participants << participant
      end
    end
    
    ordered_participants = ScheduleParticipant.by_enrollment_time
    # Should be ordered from earliest to latest enrollment
    assert_equal participants.reverse, ordered_participants.to_a[-3..-1]
  end

  # Enrollment Logic Tests
  test "should automatically enroll from waitlist when spot becomes available" do
    # Fill schedule to capacity
    @schedule.update!(max_participants: 2)
    
    enrolled_student1 = User.create!(
      email: 'enrolled1@test.com',
      password: 'password123',
      first_name: 'Enrolled',
      last_name: 'One',
      role: 'student'
    )
    
    enrolled_student2 = User.create!(
      email: 'enrolled2@test.com',
      password: 'password123',
      first_name: 'Enrolled',
      last_name: 'Two',
      role: 'student'
    )
    
    ScheduleParticipant.create!(schedule: @schedule, user: enrolled_student1, status: 'enrolled')
    ScheduleParticipant.create!(schedule: @schedule, user: enrolled_student2, status: 'enrolled')
    
    # Add waitlisted participant
    @schedule_participant.status = 'waitlisted'
    @schedule_participant.save!
    
    assert @schedule_participant.waitlisted?
    
    # Drop one enrolled participant
    enrolled_participant = @schedule.schedule_participants.enrolled.first
    enrolled_participant.update!(status: 'dropped')
    
    # Waitlisted participant should be automatically enrolled
    @schedule_participant.reload
    assert @schedule_participant.enrolled?
    assert_not_nil @schedule_participant.enrolled_at
  end

  test "should prevent enrollment when schedule is full" do
    @schedule.update!(max_participants: 1)
    
    # Enroll first student
    enrolled_student = User.create!(
      email: 'enrolled@test.com',
      password: 'password123',
      first_name: 'Enrolled',
      last_name: 'Student',
      role: 'student'
    )
    
    ScheduleParticipant.create!(schedule: @schedule, user: enrolled_student, status: 'enrolled')
    
    # Try to enroll second student - should be waitlisted
    @schedule_participant.status = 'enrolled'
    assert_not @schedule_participant.valid?
    assert_includes @schedule_participant.errors[:base], "Schedule is full. You have been added to the waitlist."
    
    # Should be valid as waitlisted
    @schedule_participant.status = 'waitlisted'
    assert @schedule_participant.valid?
  end

  # Time Conflict Validation Tests
  test "should detect participant time conflicts" do
    @schedule_participant.save!
    
    # Create overlapping schedule
    overlapping_schedule = Schedule.create!(
      title: 'Conflicting Class',
      description: 'This conflicts with existing enrollment',
      location: 'Room 102',
      start_time: @schedule.start_time + 30.minutes,
      end_time: @schedule.end_time + 30.minutes,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    conflicting_participant = ScheduleParticipant.new(
      schedule: overlapping_schedule,
      user: @student,  # Same student
      status: 'enrolled'
    )
    
    assert_not conflicting_participant.valid?
    assert_includes conflicting_participant.errors[:base], "You have a scheduling conflict with another enrolled class"
  end

  test "should allow enrollment in non-overlapping schedules" do
    @schedule_participant.save!
    
    # Create non-overlapping schedule
    non_overlapping_schedule = Schedule.create!(
      title: 'Non-conflicting Class',
      description: 'This does not conflict',
      location: 'Room 102',
      start_time: @schedule.end_time + 1.hour,
      end_time: @schedule.end_time + 3.hours,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    non_conflicting_participant = ScheduleParticipant.new(
      schedule: non_overlapping_schedule,
      user: @student,
      status: 'enrolled'
    )
    
    assert non_conflicting_participant.valid?
  end

  test "should not check conflicts for waitlisted participants" do
    @schedule_participant.save!
    
    # Create overlapping schedule
    overlapping_schedule = Schedule.create!(
      title: 'Conflicting Class',
      description: 'This would conflict if enrolled',
      location: 'Room 102',
      start_time: @schedule.start_time + 30.minutes,
      end_time: @schedule.end_time + 30.minutes,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    waitlisted_participant = ScheduleParticipant.new(
      schedule: overlapping_schedule,
      user: @student,
      status: 'waitlisted'  # Waitlisted should not check conflicts
    )
    
    assert waitlisted_participant.valid?
  end

  test "should not check conflicts for dropped participants" do
    @schedule_participant.save!
    
    overlapping_schedule = Schedule.create!(
      title: 'Conflicting Class',
      description: 'This would conflict if enrolled',
      location: 'Room 102',
      start_time: @schedule.start_time + 30.minutes,
      end_time: @schedule.end_time + 30.minutes,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    dropped_participant = ScheduleParticipant.new(
      schedule: overlapping_schedule,
      user: @student,
      status: 'dropped'
    )
    
    assert dropped_participant.valid?
  end

  # Business Logic Tests
  test "should calculate enrollment duration" do
    @schedule_participant.save!
    
    travel_to 1.week.from_now do
      @schedule_participant.update!(status: 'completed')
      
      duration = @schedule_participant.enrollment_duration_days
      assert_equal 7, duration
    end
  end

  test "should handle enrollment duration for non-completed participants" do
    @schedule_participant.save!
    
    travel_to 3.days.from_now do
      duration = @schedule_participant.enrollment_duration_days
      assert_equal 3, duration
    end
  end

  test "should provide status display text" do
    @schedule_participant.status = 'enrolled'
    @schedule_participant.save!
    assert_equal 'Enrolled', @schedule_participant.status_display
    
    @schedule_participant.update!(status: 'waitlisted')
    assert_equal 'Waitlisted', @schedule_participant.status_display
    
    @schedule_participant.update!(status: 'dropped')
    assert_equal 'Dropped', @schedule_participant.status_display
    
    @schedule_participant.update!(status: 'completed')
    assert_equal 'Completed', @schedule_participant.status_display
  end

  # Statistical Tests
  test "should contribute to schedule statistics" do
    @schedule_participant.save!
    
    assert_equal 1, @schedule.current_enrollment
    assert_equal 29, @schedule.available_spots
    
    @schedule_participant.update!(status: 'dropped')
    assert_equal 0, @schedule.reload.current_enrollment
    assert_equal 30, @schedule.available_spots
  end

  # Edge Cases
  test "should handle rapid status changes" do
    @schedule_participant.save!
    
    # Rapidly change status multiple times
    @schedule_participant.update!(status: 'waitlisted')
    @schedule_participant.update!(status: 'enrolled')
    @schedule_participant.update!(status: 'dropped')
    @schedule_participant.update!(status: 'enrolled')
    
    assert @schedule_participant.enrolled?
    assert_not_nil @schedule_participant.enrolled_at
  end

  test "should handle boundary time conditions for conflicts" do
    @schedule_participant.save!
    
    # Schedule that starts exactly when other ends
    adjacent_schedule = Schedule.create!(
      title: 'Adjacent Class',
      description: 'Starts when other ends',
      location: 'Room 102',
      start_time: @schedule.end_time,
      end_time: @schedule.end_time + 2.hours,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    adjacent_participant = ScheduleParticipant.new(
      schedule: adjacent_schedule,
      user: @student,
      status: 'enrolled'
    )
    
    # Adjacent schedules should not conflict
    assert adjacent_participant.valid?
  end

  # Performance Tests
  test "should efficiently check for conflicts" do
    @schedule_participant.save!
    
    # Create many non-conflicting schedules for the user
    10.times do |i|
      other_schedule = Schedule.create!(
        title: "Class #{i}",
        description: "Non-conflicting class #{i}",
        location: "Room #{i}",
        start_time: @schedule.end_time + (i + 1).hours,
        end_time: @schedule.end_time + (i + 2).hours,
        user: @teacher,
        department: @department,
        max_participants: 20,
        schedule_type: 'class'
      )
      
      ScheduleParticipant.create!(
        schedule: other_schedule,
        user: @student,
        status: 'enrolled'
      )
    end
    
    # Adding one more non-conflicting participant should still be efficient
    final_schedule = Schedule.create!(
      title: 'Final Class',
      description: 'One more non-conflicting class',
      location: 'Final Room',
      start_time: @schedule.end_time + 12.hours,
      end_time: @schedule.end_time + 14.hours,
      user: @teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    final_participant = ScheduleParticipant.new(
      schedule: final_schedule,
      user: @student,
      status: 'enrolled'
    )
    
    assert final_participant.valid?
  end
end