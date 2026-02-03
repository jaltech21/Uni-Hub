require 'test_helper'

class SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
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
  end

  # Teacher Tests
  test "teacher should get schedules index" do
    sign_in @teacher
    get schedules_url
    assert_response :success
    assert_select 'h1', /Schedules/
    assert_select '.schedule-card'
    assert_select '.calendar-view'
  end

  test "teacher should get new schedule form" do
    sign_in @teacher
    get new_schedule_url
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="schedule[title]"]'
    assert_select 'textarea[name="schedule[description]"]'
    assert_select 'input[name="schedule[location]"]'
    assert_select 'input[name="schedule[start_time]"]'
    assert_select 'input[name="schedule[end_time]"]'
    assert_select 'input[name="schedule[max_participants]"]'
    assert_select 'select[name="schedule[schedule_type]"]'
  end

  test "teacher should create schedule" do
    sign_in @teacher
    
    assert_difference('Schedule.count') do
      post schedules_url, params: {
        schedule: {
          title: 'New Database Class',
          description: 'Introduction to database systems',
          location: 'Room 205',
          start_time: 2.days.from_now,
          end_time: 2.days.from_now + 1.5.hours,
          max_participants: 25,
          schedule_type: 'class'
        }
      }
    end
    
    assert_redirected_to schedule_path(Schedule.last)
    follow_redirect!
    assert_match 'Schedule was successfully created', flash[:notice]
  end

  test "teacher should show schedule with enrollment management" do
    sign_in @teacher
    get schedule_url(@schedule)
    assert_response :success
    assert_select 'h1', @schedule.title
    assert_select '.schedule-details'
    assert_select '.enrollment-stats'
    assert_select '.participant-list'
    assert_select '.schedule-actions'
  end

  test "teacher should get edit form for their schedule" do
    sign_in @teacher
    get edit_schedule_url(@schedule)
    assert_response :success
    assert_select 'form'
    assert_select 'input[value=?]', @schedule.title
  end

  test "teacher should update their schedule" do
    sign_in @teacher
    
    patch schedule_url(@schedule), params: {
      schedule: {
        title: 'Updated Programming Lecture',
        description: @schedule.description,
        location: @schedule.location,
        start_time: @schedule.start_time,
        end_time: @schedule.end_time,
        max_participants: @schedule.max_participants,
        schedule_type: @schedule.schedule_type
      }
    }
    
    assert_redirected_to schedule_path(@schedule)
    @schedule.reload
    assert_equal 'Updated Programming Lecture', @schedule.title
  end

  test "teacher should destroy their schedule" do
    sign_in @teacher
    
    assert_difference('Schedule.count', -1) do
      delete schedule_url(@schedule)
    end
    
    assert_redirected_to schedules_url
    assert_match 'Schedule deleted successfully', flash[:notice]
  end

  test "teacher cannot edit other teacher's schedule" do
    other_teacher = User.create!(
      email: 'other_teacher@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    other_schedule = Schedule.create!(
      title: 'Other Teacher Schedule',
      description: 'Not accessible',
      location: 'Room 999',
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 2.hours,
      user: other_teacher,
      department: @department,
      max_participants: 20,
      schedule_type: 'class'
    )
    
    sign_in @teacher
    get edit_schedule_url(other_schedule)
    assert_redirected_to schedules_path
    assert_match 'You can only modify your own schedules', flash[:alert]
  end

  test "teacher should manage schedule participants" do
    # Add some participants
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    @schedule.schedule_participants.create!(user: @admin, status: 'waitlisted')
    
    sign_in @teacher
    get schedule_participants_schedule_url(@schedule)
    assert_response :success
    assert_select '.participant-row', count: 2
    assert_select '.enrolled-participant'
    assert_select '.waitlisted-participant'
    assert_select '.participant-actions'
  end

  test "teacher should send schedule reminders" do
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    sign_in @teacher
    
    assert_enqueued_with(job: ScheduleReminderJob) do
      post send_reminders_schedule_url(@schedule)
    end
    
    assert_redirected_to schedule_path(@schedule)
    assert_match 'Reminders sent successfully', flash[:notice]
  end

  # Student Tests
  test "student should get schedules index with enrollment view" do
    sign_in @student
    get schedules_url
    assert_response :success
    assert_select '.available-schedules'
    assert_select '.my-enrollments'
    assert_select '.schedule-calendar'
  end

  test "student should show schedule with enrollment options" do
    sign_in @student
    get schedule_url(@schedule)
    assert_response :success
    assert_select 'h1', @schedule.title
    assert_select '.schedule-details'
    assert_select '.enrollment-section'
    assert_select '.enroll-button, .waitlist-button'
  end

  test "student should enroll in schedule" do
    sign_in @student
    
    assert_difference('ScheduleParticipant.count') do
      post enroll_schedule_url(@schedule)
    end
    
    assert_redirected_to schedule_path(@schedule)
    assert_match 'Successfully enrolled', flash[:notice]
    
    participant = ScheduleParticipant.last
    assert_equal @student, participant.user
    assert_equal @schedule, participant.schedule
    assert_equal 'enrolled', participant.status
  end

  test "student should be waitlisted when schedule is full" do
    @schedule.update!(max_participants: 1)
    
    # Fill the schedule
    other_student = User.create!(
      email: 'enrolled_student@test.com',
      password: 'password123',
      first_name: 'Enrolled',
      last_name: 'Student',
      role: 'student'
    )
    @schedule.schedule_participants.create!(user: other_student, status: 'enrolled')
    
    sign_in @student
    
    assert_difference('ScheduleParticipant.count') do
      post enroll_schedule_url(@schedule)
    end
    
    participant = ScheduleParticipant.last
    assert_equal 'waitlisted', participant.status
    assert_match 'Added to waitlist', flash[:notice]
  end

  test "student should not enroll twice in same schedule" do
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    sign_in @student
    
    assert_no_difference('ScheduleParticipant.count') do
      post enroll_schedule_url(@schedule)
    end
    
    assert_redirected_to schedule_path(@schedule)
    assert_match 'You are already enrolled', flash[:alert]
  end

  test "student should drop from schedule" do
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    sign_in @student
    
    delete drop_schedule_url(@schedule)
    
    assert_redirected_to schedule_path(@schedule)
    assert_match 'Successfully dropped', flash[:notice]
    
    participant = @schedule.schedule_participants.find_by(user: @student)
    assert_equal 'dropped', participant.status
  end

  test "student should not have scheduling conflicts" do
    # Create overlapping schedule
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    
    conflicting_schedule = Schedule.create!(
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
    
    sign_in @student
    
    post enroll_schedule_url(conflicting_schedule)
    
    assert_redirected_to schedule_path(conflicting_schedule)
    assert_match 'Schedule conflict detected', flash[:alert]
  end

  test "student cannot access new schedule form" do
    sign_in @student
    get new_schedule_url
    assert_redirected_to root_path
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot create schedule" do
    sign_in @student
    
    assert_no_difference('Schedule.count') do
      post schedules_url, params: {
        schedule: {
          title: 'Student Schedule',
          description: 'Should not work',
          location: 'Nowhere',
          start_time: 1.day.from_now,
          end_time: 1.day.from_now + 2.hours,
          max_participants: 10,
          schedule_type: 'class'
        }
      }
    end
    
    assert_redirected_to root_path
  end

  test "student cannot edit schedules" do
    sign_in @student
    get edit_schedule_url(@schedule)
    assert_redirected_to root_path
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot delete schedules" do
    sign_in @student
    
    assert_no_difference('Schedule.count') do
      delete schedule_url(@schedule)
    end
    
    assert_redirected_to root_path
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get schedules_url
    assert_redirected_to new_user_session_path
    
    get schedule_url(@schedule)
    assert_redirected_to new_user_session_path
    
    get new_schedule_url
    assert_redirected_to new_user_session_path
    
    post schedules_url, params: { schedule: { title: 'Test' } }
    assert_redirected_to new_user_session_path
  end

  # Validation Tests
  test "should not create schedule with invalid data" do
    sign_in @teacher
    
    assert_no_difference('Schedule.count') do
      post schedules_url, params: {
        schedule: {
          title: '', # Invalid - blank title
          description: 'Valid description',
          location: 'Valid location',
          start_time: 1.day.from_now,
          end_time: 1.day.from_now + 2.hours,
          max_participants: 20,
          schedule_type: 'class'
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert', text: /can't be blank/
  end

  test "should not create schedule with time conflicts" do
    sign_in @teacher
    
    assert_no_difference('Schedule.count') do
      post schedules_url, params: {
        schedule: {
          title: 'Conflicting Schedule',
          description: 'This conflicts with existing schedule',
          location: 'Room 200',
          start_time: @schedule.start_time + 30.minutes,
          end_time: @schedule.end_time + 30.minutes,
          max_participants: 15,
          schedule_type: 'class'
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert', text: /conflicts with existing schedule/
  end

  # Calendar and Time Management Tests
  test "should display calendar view" do
    sign_in @teacher
    get schedules_url, params: { view: 'calendar' }
    assert_response :success
    assert_select '.calendar-container'
    assert_select '.calendar-event'
    assert_select '.month-navigation'
  end

  test "should filter schedules by date range" do
    sign_in @teacher
    
    next_week_schedule = Schedule.create!(
      title: 'Next Week Class',
      description: 'Class next week',
      location: 'Room 301',
      start_time: 1.week.from_now,
      end_time: 1.week.from_now + 2.hours,
      user: @teacher,
      department: @department,
      max_participants: 25,
      schedule_type: 'class'
    )
    
    get schedules_url, params: { 
      start_date: Date.current, 
      end_date: 3.days.from_now.to_date 
    }
    assert_response :success
    assert_select '.schedule-card', text: /#{@schedule.title}/
    assert_select '.schedule-card', text: /#{next_week_schedule.title}/, count: 0
  end

  test "should filter schedules by type" do
    sign_in @teacher
    
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
    
    get schedules_url, params: { schedule_type: 'class' }
    assert_response :success
    assert_select '.schedule-card', text: /#{@schedule.title}/
    assert_select '.schedule-card', text: /#{meeting_schedule.title}/, count: 0
  end

  # Email and Notification Tests
  test "should handle reminder scheduling" do
    sign_in @teacher
    
    @schedule.update!(start_time: 25.hours.from_now)  # Should trigger reminder
    
    get schedule_url(@schedule)
    assert_response :success
    assert_select '.reminder-info'
    assert_select '.send-reminder-button'
  end

  test "should show reminder status" do
    @schedule.update!(reminder_sent_at: Time.current)
    
    sign_in @teacher
    get schedule_url(@schedule)
    assert_response :success
    assert_select '.reminder-sent-status'
  end

  # Waitlist Management Tests
  test "teacher should manage waitlist" do
    @schedule.update!(max_participants: 1)
    
    # Fill schedule and add to waitlist
    enrolled_student = User.create!(
      email: 'enrolled@test.com',
      password: 'password123',
      first_name: 'Enrolled',
      last_name: 'Student',
      role: 'student'
    )
    
    waitlisted_student = User.create!(
      email: 'waitlisted@test.com',
      password: 'password123',
      first_name: 'Waitlisted',
      last_name: 'Student',
      role: 'student'
    )
    
    @schedule.schedule_participants.create!(user: enrolled_student, status: 'enrolled')
    @schedule.schedule_participants.create!(user: waitlisted_student, status: 'waitlisted')
    
    sign_in @teacher
    get waitlist_schedule_url(@schedule)
    assert_response :success
    assert_select '.waitlist-participant'
    assert_select '.promote-to-enrolled-button'
  end

  test "teacher should promote from waitlist" do
    @schedule.schedule_participants.create!(user: @student, status: 'waitlisted')
    
    sign_in @teacher
    
    patch promote_from_waitlist_schedule_url(@schedule), params: { user_id: @student.id }
    
    assert_redirected_to schedule_path(@schedule)
    assert_match 'Student promoted from waitlist', flash[:notice]
    
    @student.schedule_participants.find_by(schedule: @schedule).tap do |participant|
      assert_equal 'enrolled', participant.status
    end
  end

  # Export and Reporting Tests
  test "teacher should export participant list to CSV" do
    @schedule.schedule_participants.create!(user: @student, status: 'enrolled')
    @schedule.schedule_participants.create!(user: @admin, status: 'waitlisted')
    
    sign_in @teacher
    
    get schedule_url(@schedule, format: :csv)
    assert_response :success
    assert_equal 'text/csv', response.content_type.split(';').first
    
    csv_content = response.body
    assert_match 'Student Name,Email,Status,Enrolled At', csv_content
    assert_match @student.full_name, csv_content
    assert_match @admin.full_name, csv_content
  end

  test "should generate schedule report" do
    sign_in @teacher
    
    get report_schedule_url(@schedule)
    assert_response :success
    assert_select '.schedule-report'
    assert_select '.enrollment-summary'
    assert_select '.participant-details'
  end

  # Mobile and API Tests
  test "should respond to JSON requests" do
    sign_in @teacher
    
    get schedules_url, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should show schedule in JSON format" do
    sign_in @teacher
    
    get schedule_url(@schedule), headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @schedule.title, json_response['title']
    assert_equal @schedule.description, json_response['description']
    assert json_response.key?('enrollment_stats')
  end

  test "should handle mobile enrollment" do
    sign_in @student
    
    post enroll_schedule_url(@schedule), headers: { 'User-Agent' => 'Mobile App' }
    
    assert_redirected_to schedule_path(@schedule)
    assert ScheduleParticipant.exists?(user: @student, schedule: @schedule)
  end

  # Performance and Scalability Tests
  test "should efficiently load schedules with participants" do
    # Create many schedules and participants
    10.times do |i|
      schedule = Schedule.create!(
        title: "Performance Schedule #{i}",
        description: "Performance testing #{i}",
        location: "Room #{i}",
        start_time: (i + 1).days.from_now,
        end_time: (i + 1).days.from_now + 2.hours,
        user: @teacher,
        department: @department,
        max_participants: 20,
        schedule_type: 'class'
      )
      
      5.times do |j|
        student = User.create!(
          email: "perf_student_#{i}_#{j}@test.com",
          password: 'password123',
          first_name: 'Student',
          last_name: "#{i}_#{j}",
          role: 'student'
        )
        schedule.schedule_participants.create!(user: student, status: 'enrolled')
      end
    end
    
    sign_in @teacher
    get schedules_url
    assert_response :success
  end

  # Error Handling Tests
  test "should handle invalid schedule ID gracefully" do
    sign_in @teacher
    
    get schedule_url(99999)
    assert_response :not_found
  end

  test "should handle enrollment in non-existent schedule" do
    sign_in @student
    
    post "/schedules/99999/enroll"
    assert_response :not_found
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end
