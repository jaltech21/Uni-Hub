require 'test_helper'

class AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
    @department = departments(:computer_science)
    
    @assignment = Assignment.create!(
      title: 'Test Assignment',
      description: 'This is a test assignment',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
  end

  # Teacher Tests
  test "teacher should get assignments index" do
    sign_in @teacher
    get assignments_url
    assert_response :success
    assert_select 'h1', /Assignments/
  end

  test "teacher should get new assignment form" do
    sign_in @teacher
    get new_assignment_url
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="assignment[title]"]'
    assert_select 'textarea[name="assignment[description]"]'
    assert_select 'input[name="assignment[due_date]"]'
  end

  test "teacher should create assignment" do
    sign_in @teacher
    
    assert_difference('Assignment.count') do
      post assignments_url, params: {
        assignment: {
          title: 'New Assignment',
          description: 'This is a new assignment',
          due_date: 2.weeks.from_now,
          points: 50,
          category: 'project'
        }
      }
    end
    
    assert_redirected_to assignment_path(Assignment.last)
    follow_redirect!
    assert_match 'Assignment was successfully created', flash[:notice]
  end

  test "teacher should show assignment with statistics" do
    sign_in @teacher
    get assignment_url(@assignment)
    assert_response :success
    assert_select 'h1', @assignment.title
    assert_select '.assignment-stats'
  end

  test "teacher should get edit form for their assignment" do
    sign_in @teacher
    get edit_assignment_url(@assignment)
    assert_response :success
    assert_select 'form'
    assert_select 'input[value=?]', @assignment.title
  end

  test "teacher should update their assignment" do
    sign_in @teacher
    
    patch assignment_url(@assignment), params: {
      assignment: {
        title: 'Updated Assignment Title',
        description: @assignment.description,
        due_date: @assignment.due_date,
        points: @assignment.points,
        category: @assignment.category
      }
    }
    
    assert_redirected_to assignment_path(@assignment)
    @assignment.reload
    assert_equal 'Updated Assignment Title', @assignment.title
  end

  test "teacher should destroy their assignment" do
    sign_in @teacher
    
    assert_difference('Assignment.count', -1) do
      delete assignment_url(@assignment)
    end
    
    assert_redirected_to assignments_url
    assert_match 'Assignment deleted successfully', flash[:notice]
  end

  test "teacher cannot edit other teacher's assignment" do
    other_teacher = User.create!(
      email: 'other_teacher@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    other_assignment = Assignment.create!(
      title: 'Other Assignment',
      description: 'Assignment by other teacher',
      due_date: 1.week.from_now,
      user: other_teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
    
    sign_in @teacher
    get edit_assignment_url(other_assignment)
    assert_redirected_to assignments_path
    assert_match 'You can only modify your own assignments', flash[:alert]
  end

  # Student Tests
  test "student should get assignments index with different view" do
    sign_in @student
    get assignments_url
    assert_response :success
    # Students see assignments ordered by due date, not creation date
    assert_select '.assignment-card'
  end

  test "student should show assignment with submission options" do
    sign_in @student
    get assignment_url(@assignment)
    assert_response :success
    assert_select 'h1', @assignment.title
    # Should show submission interface for students
    assert_select '.submission-section'
  end

  test "student cannot access new assignment form" do
    sign_in @student
    get new_assignment_url
    assert_redirected_to root_path
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot create assignment" do
    sign_in @student
    
    assert_no_difference('Assignment.count') do
      post assignments_url, params: {
        assignment: {
          title: 'Student Assignment',
          description: 'Students should not create assignments',
          due_date: 1.week.from_now,
          points: 50,
          category: 'homework'
        }
      }
    end
    
    assert_redirected_to root_path
  end

  test "student cannot edit assignments" do
    sign_in @student
    get edit_assignment_url(@assignment)
    assert_redirected_to root_path
    assert_match 'You are not authorized', flash[:alert]
  end

  test "student cannot delete assignments" do
    sign_in @student
    
    assert_no_difference('Assignment.count') do
      delete assignment_url(@assignment)
    end
    
    assert_redirected_to root_path
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get assignments_url
    assert_redirected_to new_user_session_path
    
    get assignment_url(@assignment)
    assert_redirected_to new_user_session_path
    
    get new_assignment_url
    assert_redirected_to new_user_session_path
    
    post assignments_url, params: { assignment: { title: 'Test' } }
    assert_redirected_to new_user_session_path
  end

  # Validation Tests
  test "should not create assignment with invalid data" do
    sign_in @teacher
    
    assert_no_difference('Assignment.count') do
      post assignments_url, params: {
        assignment: {
          title: '', # Invalid - blank title
          description: 'Valid description',
          due_date: 1.week.from_now,
          points: 100,
          category: 'homework'
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert', text: /can't be blank/
  end

  test "should not update assignment with invalid data" do
    sign_in @teacher
    
    patch assignment_url(@assignment), params: {
      assignment: {
        title: '', # Invalid - blank title
        description: @assignment.description,
        due_date: @assignment.due_date,
        points: @assignment.points,
        category: @assignment.category
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert'
  end

  # Department Filtering Tests
  test "should filter assignments by department" do
    sign_in @teacher
    
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_assignment = Assignment.create!(
      title: 'Physics Assignment',
      description: 'Physics assignment',
      due_date: 1.week.from_now,
      user: @teacher,
      department: physics_dept,
      points: 100,
      category: 'homework'
    )
    
    get assignments_url, params: { department_id: @department.id }
    assert_response :success
    assert_select '.assignment-card', text: /#{@assignment.title}/
    assert_select '.assignment-card', text: /#{physics_assignment.title}/, count: 0
  end

  # File Upload Tests
  test "should handle file attachments in assignment creation" do
    sign_in @teacher
    
    # This would require actual file upload testing with fixtures
    # For now, we test that the parameter is accepted
    post assignments_url, params: {
      assignment: {
        title: 'Assignment with Files',
        description: 'This assignment has file attachments',
        due_date: 1.week.from_now,
        points: 100,
        category: 'project',
        files: [] # Empty array is acceptable
      }
    }
    
    assert_redirected_to assignment_path(Assignment.last)
  end

  # Statistics Tests
  test "teacher should see assignment statistics" do
    sign_in @teacher
    
    # Create submissions for statistics
    @assignment.submissions.create!(user: @student, status: 'submitted', submitted_at: Time.current)
    @assignment.submissions.create!(user: @admin, status: 'graded', grade: 85, graded_by: @teacher)
    
    get assignment_url(@assignment)
    assert_response :success
    assert_select '.assignment-stats .submitted-count', text: /1/
    assert_select '.assignment-stats .graded-count', text: /1/
  end

  # JSON API Tests
  test "should respond to JSON requests" do
    sign_in @teacher
    
    get assignments_url, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should show assignment in JSON format" do
    sign_in @teacher
    
    get assignment_url(@assignment), headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @assignment.title, json_response['title']
    assert_equal @assignment.description, json_response['description']
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end