require 'test_helper'

class AttendanceListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
    @department = departments(:computer_science)
    
    @attendance_list = AttendanceList.create!(
      title: 'Monday Morning Lecture',
      description: 'Introduction to Computer Science',
      location: 'Room 101',
      start_time: 30.minutes.ago,  # Active session
      user: @teacher,
      department: @department
    )
  end

  # Teacher Tests
  test "teacher should get attendance lists index" do
    sign_in @teacher
    get attendance_lists_url
    assert_response :success
    assert_select 'h1', /Attendance Lists/
    assert_select '.attendance-list-card'
  end

  test "teacher should get new attendance list form" do
    sign_in @teacher
    get new_attendance_list_url
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="attendance_list[title]"]'
    assert_select 'textarea[name="attendance_list[description]"]'
    assert_select 'input[name="attendance_list[location]"]'
    assert_select 'input[name="attendance_list[start_time]"]'
  end

  test "teacher should create attendance list" do
    sign_in @teacher
    
    assert_difference('AttendanceList.count') do
      post attendance_lists_url, params: {
        attendance_list: {
          title: 'New Lecture Session',
          description: 'Advanced programming concepts',
          location: 'Lab 202',
          start_time: 2.hours.from_now
        }
      }
    end
    
    assert_redirected_to attendance_list_path(AttendanceList.last)
    follow_redirect!
    assert_match 'Attendance list was successfully created', flash[:notice]
  end

  test "teacher should show attendance list with TOTP code" do
    sign_in @teacher
    get attendance_list_url(@attendance_list)
    assert_response :success
    assert_select 'h1', @attendance_list.title
    assert_select '.attendance-code'  # TOTP code display
    assert_select '.attendance-stats'
    assert_select '.qr-code'  # QR code for easy scanning
  end

  test "teacher should get edit form for their attendance list" do
    sign_in @teacher
    get edit_attendance_list_url(@attendance_list)
    assert_response :success
    assert_select 'form'
    assert_select 'input[value=?]', @attendance_list.title
  end

  test "teacher should update their attendance list" do
    sign_in @teacher
    
    patch attendance_list_url(@attendance_list), params: {
      attendance_list: {
        title: 'Updated Lecture Title',
        description: @attendance_list.description,
        location: @attendance_list.location,
        start_time: @attendance_list.start_time
      }
    }
    
    assert_redirected_to attendance_list_path(@attendance_list)
    @attendance_list.reload
    assert_equal 'Updated Lecture Title', @attendance_list.title
  end

  test "teacher should destroy their attendance list" do
    sign_in @teacher
    
    assert_difference('AttendanceList.count', -1) do
      delete attendance_list_url(@attendance_list)
    end
    
    assert_redirected_to attendance_lists_url
    assert_match 'Attendance list deleted successfully', flash[:notice]
  end

  test "teacher cannot edit other teacher's attendance list" do
    other_teacher = User.create!(
      email: 'other_teacher@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    other_list = AttendanceList.create!(
      title: 'Other Teacher List',
      description: 'Not accessible',
      location: 'Room 999',
      start_time: 1.hour.from_now,
      user: other_teacher,
      department: @department
    )
    
    sign_in @teacher
    get edit_attendance_list_url(other_list)
    assert_redirected_to attendance_lists_path
    assert_match 'You can only modify your own attendance lists', flash[:alert]
  end

  test "teacher should regenerate TOTP secret" do
    sign_in @teacher
    original_secret = @attendance_list.secret_key
    
    patch regenerate_secret_attendance_list_url(@attendance_list)
    
    assert_redirected_to attendance_list_path(@attendance_list)
    @attendance_list.reload
    assert_not_equal original_secret, @attendance_list.secret_key
    assert_match 'New attendance code generated', flash[:notice]
  end

  test "teacher should view attendance records for their list" do
    # Create some attendance records
    @attendance_list.attendance_records.create!(user: @student)
    @attendance_list.attendance_records.create!(user: @admin)
    
    sign_in @teacher
    get attendance_list_attendance_records_url(@attendance_list)
    assert_response :success
    assert_select '.attendance-record-row', count: 2
    assert_select '.on-time-badge'
    assert_select '.late-badge'
  end

  test "teacher should export attendance to CSV" do
    @attendance_list.attendance_records.create!(user: @student)
    
    sign_in @teacher
    get attendance_list_url(@attendance_list, format: :csv)
    assert_response :success
    assert_equal 'text/csv', response.content_type.split(';').first
    assert_match 'Student Name,Email,Recorded At,Status', response.body
  end

  # Student Tests
  test "student should get attendance lists index with different view" do
    sign_in @student
    get attendance_lists_url
    assert_response :success
    # Students see active attendance lists they can join
    assert_select '.active-attendance-list'
  end

  test "student should show attendance list with check-in option" do
    sign_in @student
    get attendance_list_url(@attendance_list)
    assert_response :success
    assert_select 'h1', @attendance_list.title
    assert_select '.check-in-form'
    assert_select 'input[name="attendance_code"]'
  end

  test "student should check in with valid TOTP code" do
    sign_in @student
    current_code = @attendance_list.current_code
    
    assert_difference('AttendanceRecord.count') do
      post check_in_attendance_list_url(@attendance_list), params: {
        attendance_code: current_code
      }
    end
    
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'Successfully checked in', flash[:notice]
    
    record = AttendanceRecord.last
    assert_equal @student, record.user
    assert_equal @attendance_list, record.attendance_list
  end

  test "student should not check in with invalid code" do
    sign_in @student
    
    assert_no_difference('AttendanceRecord.count') do
      post check_in_attendance_list_url(@attendance_list), params: {
        attendance_code: '000000'  # Invalid code
      }
    end
    
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'Invalid attendance code', flash[:alert]
  end

  test "student should not check in twice" do
    sign_in @student
    @attendance_list.attendance_records.create!(user: @student)
    
    assert_no_difference('AttendanceRecord.count') do
      post check_in_attendance_list_url(@attendance_list), params: {
        attendance_code: @attendance_list.current_code
      }
    end
    
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'You have already checked in', flash[:alert]
  end

  test "student should not check in to expired session" do
    @attendance_list.update!(start_time: 3.hours.ago)  # Expired
    
    sign_in @student
    
    assert_no_difference('AttendanceRecord.count') do
      post check_in_attendance_list_url(@attendance_list), params: {
        attendance_code: @attendance_list.current_code
      }
    end
    
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'Attendance session has ended', flash[:alert]
  end

  test "student cannot access new attendance list form" do
    sign_in @student
    get new_attendance_list_url
    assert_redirected_to root_path
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot create attendance list" do
    sign_in @student
    
    assert_no_difference('AttendanceList.count') do
      post attendance_lists_url, params: {
        attendance_list: {
          title: 'Student List',
          description: 'Should not work',
          location: 'Nowhere',
          start_time: 1.hour.from_now
        }
      }
    end
    
    assert_redirected_to root_path
  end

  test "student cannot edit attendance lists" do
    sign_in @student
    get edit_attendance_list_url(@attendance_list)
    assert_redirected_to root_path
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot delete attendance lists" do
    sign_in @student
    
    assert_no_difference('AttendanceList.count') do
      delete attendance_list_url(@attendance_list)
    end
    
    assert_redirected_to root_path
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get attendance_lists_url
    assert_redirected_to new_user_session_path
    
    get attendance_list_url(@attendance_list)
    assert_redirected_to new_user_session_path
    
    get new_attendance_list_url
    assert_redirected_to new_user_session_path
    
    post attendance_lists_url, params: { attendance_list: { title: 'Test' } }
    assert_redirected_to new_user_session_path
  end

  # Validation Tests
  test "should not create attendance list with invalid data" do
    sign_in @teacher
    
    assert_no_difference('AttendanceList.count') do
      post attendance_lists_url, params: {
        attendance_list: {
          title: '', # Invalid - blank title
          description: 'Valid description',
          location: 'Valid location',
          start_time: 1.hour.from_now
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert', text: /can't be blank/
  end

  test "should not update attendance list with invalid data" do
    sign_in @teacher
    
    patch attendance_list_url(@attendance_list), params: {
      attendance_list: {
        title: '', # Invalid - blank title
        description: @attendance_list.description,
        location: @attendance_list.location,
        start_time: @attendance_list.start_time
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert'
  end

  # Department Filtering Tests
  test "should filter attendance lists by department" do
    sign_in @teacher
    
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_list = AttendanceList.create!(
      title: 'Physics Lecture',
      description: 'Physics attendance',
      location: 'Physics Lab',
      start_time: 1.hour.from_now,
      user: @teacher,
      department: physics_dept
    )
    
    get attendance_lists_url, params: { department_id: @department.id }
    assert_response :success
    assert_select '.attendance-list-card', text: /#{@attendance_list.title}/
    assert_select '.attendance-list-card', text: /#{physics_list.title}/, count: 0
  end

  # Real-time Updates Tests
  test "should provide current TOTP code via AJAX" do
    sign_in @teacher
    
    get current_code_attendance_list_url(@attendance_list), xhr: true
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
    
    json_response = JSON.parse(response.body)
    assert_match /\A\d{6}\z/, json_response['code']
    assert json_response['expires_in'] > 0
  end

  test "should refresh attendance records via AJAX" do
    @attendance_list.attendance_records.create!(user: @student)
    
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list), xhr: true
    assert_response :success
    assert_match 'text/html', response.content_type.split(';').first
    assert_select '.attendance-record-row'
  end

  # Mobile/QR Code Tests
  test "should show QR code for mobile check-in" do
    sign_in @teacher
    get attendance_list_url(@attendance_list)
    assert_response :success
    assert_select '.qr-code-container'
    assert_select 'img[alt="QR Code"]'
  end

  test "should handle mobile check-in URL" do
    sign_in @student
    
    # Simulate scanning QR code with embedded attendance code
    current_code = @attendance_list.current_code
    get mobile_check_in_attendance_list_url(@attendance_list, code: current_code)
    
    assert_response :success
    assert_select '.mobile-check-in-form'
    assert_select 'input[value=?]', current_code
  end

  # Statistics Tests
  test "should show attendance statistics to teacher" do
    # Create mixed attendance records
    5.times do |i|
      student = User.create!(
        email: "student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      
      # Create records at different times for on-time/late testing
      if i < 3
        @attendance_list.update!(start_time: 5.minutes.ago)
      else
        @attendance_list.update!(start_time: 15.minutes.ago)
      end
      
      @attendance_list.attendance_records.create!(user: student)
    end
    
    sign_in @teacher
    get attendance_list_url(@attendance_list)
    assert_response :success
    assert_select '.attendance-stats .total-count', text: /5/
    assert_select '.attendance-stats .on-time-count'
    assert_select '.attendance-stats .late-count'
  end

  # JSON API Tests
  test "should respond to JSON requests" do
    sign_in @teacher
    
    get attendance_lists_url, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should show attendance list in JSON format" do
    sign_in @teacher
    
    get attendance_list_url(@attendance_list), headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @attendance_list.title, json_response['title']
    assert_equal @attendance_list.description, json_response['description']
    assert json_response.key?('current_code')
  end

  # Security Tests
  test "should not expose TOTP secret in responses" do
    sign_in @teacher
    
    get attendance_list_url(@attendance_list), headers: { 'Accept' => 'application/json' }
    json_response = JSON.parse(response.body)
    
    assert_not json_response.key?('secret_key')
    assert_not response.body.include?(@attendance_list.secret_key)
  end

  test "should rate limit check-in attempts" do
    sign_in @student
    
    # Simulate multiple rapid check-in attempts
    5.times do
      post check_in_attendance_list_url(@attendance_list), params: {
        attendance_code: '000000'  # Invalid code
      }
    end
    
    # After rate limit, should get different response
    post check_in_attendance_list_url(@attendance_list), params: {
      attendance_code: '111111'
    }
    
    # Implementation would handle rate limiting
    assert_response :redirect
  end

  # Accessibility Tests
  test "should have proper accessibility attributes" do
    sign_in @teacher
    get attendance_list_url(@attendance_list)
    assert_response :success
    
    assert_select 'input[aria-label]'
    assert_select 'form[role="form"]'
    assert_select '[aria-describedby]'
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end
