require 'test_helper'

class AttendanceRecordsControllerTest < ActionDispatch::IntegrationTest
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
    
    @attendance_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: @student
    )
  end

  # Teacher Tests - Viewing Records
  test "teacher should get attendance records index for their list" do
    sign_in @teacher
    get attendance_list_attendance_records_url(@attendance_list)
    assert_response :success
    assert_select 'h1', /Attendance Records/
    assert_select '.attendance-record-row'
    assert_select '.student-name'
    assert_select '.check-in-time'
    assert_select '.status-badge'
  end

  test "teacher should show individual attendance record" do
    sign_in @teacher
    get attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    assert_response :success
    assert_select 'h1', /Attendance Record/
    assert_select '.student-info'
    assert_select '.attendance-details'
    assert_select '.record-timestamp'
  end

  test "teacher should edit attendance record" do
    sign_in @teacher
    get edit_attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    assert_response :success
    assert_select 'form'
    assert_select 'textarea[name="attendance_record[notes]"]'
    assert_select 'select[name="attendance_record[status]"]'
  end

  test "teacher should update attendance record" do
    sign_in @teacher
    
    patch attendance_list_attendance_record_url(@attendance_list, @attendance_record), params: {
      attendance_record: {
        notes: 'Student arrived late due to traffic',
        status: 'late'
      }
    }
    
    assert_redirected_to attendance_list_attendance_record_path(@attendance_list, @attendance_record)
    @attendance_record.reload
    assert_equal 'Student arrived late due to traffic', @attendance_record.notes
    assert_match 'Attendance record updated successfully', flash[:notice]
  end

  test "teacher should delete attendance record" do
    sign_in @teacher
    
    assert_difference('AttendanceRecord.count', -1) do
      delete attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    end
    
    assert_redirected_to attendance_list_attendance_records_path(@attendance_list)
    assert_match 'Attendance record deleted successfully', flash[:notice]
  end

  test "teacher cannot access records from other teacher's lists" do
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
      start_time: 1.hour.ago,
      user: other_teacher,
      department: @department
    )
    
    other_record = AttendanceRecord.create!(
      attendance_list: other_list,
      user: @student
    )
    
    sign_in @teacher
    get attendance_list_attendance_records_url(other_list)
    assert_redirected_to attendance_lists_path
    assert_match 'You can only view records for your attendance lists', flash[:alert]
  end

  test "teacher should bulk update attendance records" do
    # Create additional records
    student2 = User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    )
    
    record2 = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: student2
    )
    
    sign_in @teacher
    
    patch bulk_update_attendance_list_attendance_records_url(@attendance_list), params: {
      attendance_records: {
        @attendance_record.id => { status: 'present', notes: 'On time' },
        record2.id => { status: 'late', notes: 'Arrived 10 minutes late' }
      }
    }
    
    assert_redirected_to attendance_list_attendance_records_path(@attendance_list)
    
    @attendance_record.reload
    record2.reload
    
    assert_equal 'On time', @attendance_record.notes
    assert_equal 'Arrived 10 minutes late', record2.notes
    assert_match 'Attendance records updated successfully', flash[:notice]
  end

  test "teacher should export attendance records to CSV" do
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list, format: :csv)
    assert_response :success
    assert_equal 'text/csv', response.content_type.split(';').first
    
    csv_content = response.body
    assert_match 'Student Name,Email,Check-in Time,Status,Notes', csv_content
    assert_match @student.full_name, csv_content
    assert_match @student.email, csv_content
  end

  test "teacher should export attendance records to PDF" do
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list, format: :pdf)
    assert_response :success
    assert_equal 'application/pdf', response.content_type.split(';').first
    
    # Check PDF filename
    assert_match /attachment; filename=.*\.pdf/, response.headers['Content-Disposition']
  end

  # Student Tests - Limited Access
  test "student should view their own attendance record" do
    sign_in @student
    get attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    assert_response :success
    assert_select 'h1', /Your Attendance Record/
    assert_select '.attendance-details'
    assert_select '.check-in-confirmation'
  end

  test "student cannot view other students' attendance records" do
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
    
    sign_in @student
    get attendance_list_attendance_record_url(@attendance_list, other_record)
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'You can only view your own attendance records', flash[:alert]
  end

  test "student cannot access attendance records index" do
    sign_in @student
    get attendance_list_attendance_records_url(@attendance_list)
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot edit attendance records" do
    sign_in @student
    get edit_attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    assert_redirected_to attendance_list_path(@attendance_list)
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot delete attendance records" do
    sign_in @student
    
    assert_no_difference('AttendanceRecord.count') do
      delete attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    end
    
    assert_redirected_to attendance_list_path(@attendance_list)
  end

  # Manual Check-in Tests (Teacher functionality)
  test "teacher should manually check in student" do
    sign_in @teacher
    
    other_student = User.create!(
      email: 'manual_student@test.com',
      password: 'password123',
      first_name: 'Manual',
      last_name: 'Student',
      role: 'student'
    )
    
    assert_difference('AttendanceRecord.count') do
      post attendance_list_attendance_records_url(@attendance_list), params: {
        attendance_record: {
          user_id: other_student.id,
          notes: 'Manually checked in by teacher',
          status: 'present'
        }
      }
    end
    
    record = AttendanceRecord.last
    assert_equal other_student, record.user
    assert_equal @attendance_list, record.attendance_list
    assert_equal 'Manually checked in by teacher', record.notes
    
    assert_redirected_to attendance_list_attendance_records_path(@attendance_list)
    assert_match 'Student checked in successfully', flash[:notice]
  end

  test "teacher cannot manually check in same student twice" do
    sign_in @teacher
    
    assert_no_difference('AttendanceRecord.count') do
      post attendance_list_attendance_records_url(@attendance_list), params: {
        attendance_record: {
          user_id: @student.id,  # Already has attendance record
          notes: 'Duplicate attempt',
          status: 'present'
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.error-message', text: /already checked in/
  end

  # Search and Filtering Tests
  test "teacher should filter attendance records by status" do
    # Create records with different statuses
    late_student = User.create!(
      email: 'late_student@test.com',
      password: 'password123',
      first_name: 'Late',
      last_name: 'Student',
      role: 'student'
    )
    
    # Simulate late arrival
    @attendance_list.update!(start_time: 15.minutes.ago)
    late_record = AttendanceRecord.create!(
      attendance_list: @attendance_list,
      user: late_student
    )
    
    sign_in @teacher
    
    # Filter by on-time status
    get attendance_list_attendance_records_url(@attendance_list), params: { status: 'on_time' }
    assert_response :success
    assert_select '.attendance-record-row', count: 1  # Only @attendance_record
    
    # Filter by late status
    get attendance_list_attendance_records_url(@attendance_list), params: { status: 'late' }
    assert_response :success
    assert_select '.attendance-record-row', count: 1  # Only late_record
  end

  test "teacher should search attendance records by student name" do
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list), params: { 
      search: @student.first_name 
    }
    assert_response :success
    assert_select '.attendance-record-row', count: 1
    assert_select '.student-name', text: /#{@student.first_name}/
  end

  # Real-time Updates Tests
  test "should provide real-time attendance updates via AJAX" do
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list), xhr: true
    assert_response :success
    assert_match 'text/html', response.content_type.split(';').first
    assert_select '.attendance-record-row'
  end

  test "should update attendance count via AJAX" do
    sign_in @teacher
    
    get attendance_count_attendance_list_url(@attendance_list), xhr: true
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
    
    json_response = JSON.parse(response.body)
    assert_equal 1, json_response['total_count']
    assert json_response.key?('on_time_count')
    assert json_response.key?('late_count')
  end

  # Statistics and Analytics Tests
  test "teacher should view attendance analytics" do
    # Create records with different timestamps
    5.times do |i|
      student = User.create!(
        email: "analytics_student#{i}@test.com",
        password: 'password123',
        first_name: 'Student',
        last_name: i.to_s,
        role: 'student'
      )
      
      # Vary the attendance list start time to create different statuses
      if i < 3
        @attendance_list.update!(start_time: 5.minutes.ago)  # On time
      else
        @attendance_list.update!(start_time: 20.minutes.ago)  # Late
      end
      
      AttendanceRecord.create!(
        attendance_list: @attendance_list,
        user: student
      )
    end
    
    sign_in @teacher
    get analytics_attendance_list_attendance_records_url(@attendance_list)
    assert_response :success
    assert_select '.analytics-dashboard'
    assert_select '.attendance-chart'
    assert_select '.statistics-summary'
  end

  # Mobile API Tests
  test "should provide mobile-friendly attendance records" do
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list), 
        headers: { 'Accept' => 'application/json', 'User-Agent' => 'Mobile App' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('records')
    assert json_response.key?('total_count')
    
    record_data = json_response['records'].first
    assert record_data.key?('student_name')
    assert record_data.key?('check_in_time')
    assert record_data.key?('status')
  end

  # Error Handling Tests
  test "should handle invalid attendance record ID gracefully" do
    sign_in @teacher
    
    get attendance_list_attendance_record_url(@attendance_list, 99999)
    assert_response :not_found
  end

  test "should handle attendance record from different list" do
    other_list = AttendanceList.create!(
      title: 'Other List',
      description: 'Different list',
      location: 'Room 999',
      start_time: 1.hour.ago,
      user: @teacher,
      department: @department
    )
    
    other_record = AttendanceRecord.create!(
      attendance_list: other_list,
      user: @student
    )
    
    sign_in @teacher
    get attendance_list_attendance_record_url(@attendance_list, other_record)
    assert_response :not_found
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get attendance_list_attendance_records_url(@attendance_list)
    assert_redirected_to new_user_session_path
    
    get attendance_list_attendance_record_url(@attendance_list, @attendance_record)
    assert_redirected_to new_user_session_path
    
    post attendance_list_attendance_records_url(@attendance_list), params: { attendance_record: {} }
    assert_redirected_to new_user_session_path
  end

  # JSON API Tests
  test "should respond to JSON requests with proper format" do
    sign_in @teacher
    
    get attendance_list_attendance_records_url(@attendance_list), 
        headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
    
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array) || json_response.key?('records')
  end

  test "should show attendance record in JSON format" do
    sign_in @teacher
    
    get attendance_list_attendance_record_url(@attendance_list, @attendance_record), 
        headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @attendance_record.user.full_name, json_response['student_name']
    assert json_response.key?('recorded_at')
    assert json_response.key?('status')
  end

  # Performance Tests
  test "should efficiently load attendance records with associations" do
    # Create many records
    20.times do |i|
      student = User.create!(
        email: "perf_student#{i}@test.com",
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
    
    sign_in @teacher
    
    # Should use efficient queries with includes
    get attendance_list_attendance_records_url(@attendance_list)
    assert_response :success
    assert_select '.attendance-record-row', count: 21  # 20 + original
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end