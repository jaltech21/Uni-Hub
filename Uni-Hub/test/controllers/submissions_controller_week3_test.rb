require 'test_helper'

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
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
    
    @submission = Submission.create!(
      assignment: @assignment,
      user: @student,
      status: 'draft'
    )
  end

  # Student Submission Tests
  test "student should get submission form" do
    sign_in @student
    get new_assignment_submission_url(@assignment)
    assert_response :success
    assert_select 'form'
    assert_select 'textarea[name="submission[content]"]'
    assert_select 'input[type="file"]'
  end

  test "student should create submission" do
    sign_in @student
    
    assert_difference('Submission.count') do
      post assignment_submissions_url(@assignment), params: {
        submission: {
          content: 'This is my submission content',
          status: 'draft'
        }
      }
    end
    
    submission = Submission.last
    assert_equal @student, submission.user
    assert_equal @assignment, submission.assignment
    assert_equal 'draft', submission.status
    assert_redirected_to [@assignment, submission]
  end

  test "student should show their submission" do
    sign_in @student
    get assignment_submission_url(@assignment, @submission)
    assert_response :success
    assert_select 'h1', /Submission for #{@assignment.title}/
    assert_select '.submission-content'
    assert_select '.submission-status', text: /draft/i
  end

  test "student should edit their draft submission" do
    sign_in @student
    get edit_assignment_submission_url(@assignment, @submission)
    assert_response :success
    assert_select 'form'
    assert_select 'textarea[name="submission[content]"]'
  end

  test "student should update their draft submission" do
    sign_in @student
    
    patch assignment_submission_url(@assignment, @submission), params: {
      submission: {
        content: 'Updated submission content',
        status: 'draft'
      }
    }
    
    assert_redirected_to [@assignment, @submission]
    @submission.reload
    assert_equal 'Updated submission content', @submission.content
  end

  test "student should submit their draft" do
    sign_in @student
    
    patch assignment_submission_url(@assignment, @submission), params: {
      submission: {
        content: @submission.content,
        status: 'submitted'
      }
    }
    
    assert_redirected_to [@assignment, @submission]
    @submission.reload
    assert_equal 'submitted', @submission.status
    assert_not_nil @submission.submitted_at
    assert_match 'Submission submitted successfully', flash[:notice]
  end

  test "student cannot edit submitted submission" do
    @submission.update!(status: 'submitted', submitted_at: Time.current)
    
    sign_in @student
    get edit_assignment_submission_url(@assignment, @submission)
    assert_redirected_to [@assignment, @submission]
    assert_match 'Cannot edit submitted submission', flash[:alert]
  end

  test "student cannot view other student submissions" do
    other_student = User.create!(
      email: 'other_student@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Student',
      role: 'student'
    )
    
    other_submission = Submission.create!(
      assignment: @assignment,
      user: other_student,
      status: 'submitted',
      content: 'Other student submission'
    )
    
    sign_in @student
    get assignment_submission_url(@assignment, other_submission)
    assert_redirected_to assignment_path(@assignment)
    assert_match 'You can only view your own submissions', flash[:alert]
  end

  test "student should delete their draft submission" do
    sign_in @student
    
    assert_difference('Submission.count', -1) do
      delete assignment_submission_url(@assignment, @submission)
    end
    
    assert_redirected_to assignment_path(@assignment)
    assert_match 'Submission deleted successfully', flash[:notice]
  end

  test "student cannot delete submitted submission" do
    @submission.update!(status: 'submitted', submitted_at: Time.current)
    
    sign_in @student
    
    assert_no_difference('Submission.count') do
      delete assignment_submission_url(@assignment, @submission)
    end
    
    assert_redirected_to [@assignment, @submission]
    assert_match 'Cannot delete submitted submission', flash[:alert]
  end

  # Teacher Grading Tests
  test "teacher should view all submissions for assignment" do
    # Create multiple submissions
    other_student = User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    )
    
    Submission.create!(
      assignment: @assignment,
      user: other_student,
      status: 'submitted',
      content: 'Another submission'
    )
    
    sign_in @teacher
    get assignment_submissions_url(@assignment)
    assert_response :success
    assert_select '.submission-row', count: 2
    assert_select '.grade-form'
  end

  test "teacher should view individual submission" do
    @submission.update!(status: 'submitted', content: 'Student work content')
    
    sign_in @teacher
    get assignment_submission_url(@assignment, @submission)
    assert_response :success
    assert_select 'h1', /Submission by #{@submission.user.full_name}/
    assert_select '.submission-content', text: /Student work content/
    assert_select '.grading-section'
  end

  test "teacher should grade submission with percentage" do
    @submission.update!(status: 'submitted', submitted_at: Time.current)
    
    sign_in @teacher
    
    patch assignment_submission_url(@assignment, @submission), params: {
      submission: {
        grade: 85,
        feedback: 'Good work! Consider improving the analysis section.'
      }
    }
    
    assert_redirected_to [@assignment, @submission]
    @submission.reload
    assert_equal 85, @submission.grade
    assert_equal 'graded', @submission.status
    assert_equal @teacher, @submission.graded_by
    assert_not_nil @submission.graded_at
    assert_equal 'Good work! Consider improving the analysis section.', @submission.feedback
    assert_match 'Submission graded successfully', flash[:notice]
  end

  test "teacher should grade submission with letter grade" do
    @submission.update!(status: 'submitted', submitted_at: Time.current)
    
    sign_in @teacher
    
    patch assignment_submission_url(@assignment, @submission), params: {
      submission: {
        letter_grade: 'B+',
        feedback: 'Above average work with room for improvement.'
      }
    }
    
    assert_redirected_to [@assignment, @submission]
    @submission.reload
    assert_equal 'B+', @submission.letter_grade
    assert_equal 'graded', @submission.status
    assert_equal @teacher, @submission.graded_by
    assert_not_nil @submission.graded_at
  end

  test "teacher cannot grade draft submission" do
    # Submission remains in draft status
    sign_in @teacher
    
    patch assignment_submission_url(@assignment, @submission), params: {
      submission: {
        grade: 90,
        feedback: 'Cannot grade draft'
      }
    }
    
    assert_redirected_to [@assignment, @submission]
    @submission.reload
    assert_nil @submission.grade
    assert_equal 'draft', @submission.status
    assert_match 'Can only grade submitted work', flash[:alert]
  end

  test "teacher should bulk grade submissions" do
    # Create multiple submitted submissions
    student2 = User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    )
    
    submission2 = Submission.create!(
      assignment: @assignment,
      user: student2,
      status: 'submitted',
      submitted_at: Time.current
    )
    
    @submission.update!(status: 'submitted', submitted_at: Time.current)
    
    sign_in @teacher
    
    patch bulk_grade_assignment_submissions_url(@assignment), params: {
      submissions: {
        @submission.id => { grade: 85, feedback: 'Good work' },
        submission2.id => { grade: 92, feedback: 'Excellent work' }
      }
    }
    
    assert_redirected_to assignment_submissions_path(@assignment)
    
    @submission.reload
    submission2.reload
    
    assert_equal 85, @submission.grade
    assert_equal 92, submission2.grade
    assert_equal 'graded', @submission.status
    assert_equal 'graded', submission2.status
    assert_match 'Submissions graded successfully', flash[:notice]
  end

  # Authorization Tests
  test "teacher cannot view submissions for other teacher assignments" do
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
    
    other_submission = Submission.create!(
      assignment: other_assignment,
      user: @student,
      status: 'submitted'
    )
    
    sign_in @teacher
    get assignment_submissions_url(other_assignment)
    assert_redirected_to assignments_path
    assert_match 'You can only view submissions for your assignments', flash[:alert]
  end

  test "student cannot access submissions index" do
    sign_in @student
    get assignment_submissions_url(@assignment)
    assert_redirected_to assignment_path(@assignment)
    assert_match 'You are not authorized', flash[:alert]
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get assignment_submissions_url(@assignment)
    assert_redirected_to new_user_session_path
    
    get assignment_submission_url(@assignment, @submission)
    assert_redirected_to new_user_session_path
    
    get new_assignment_submission_url(@assignment)
    assert_redirected_to new_user_session_path
  end

  # File Upload Tests
  test "should handle file attachments in submission" do
    sign_in @student
    
    post assignment_submissions_url(@assignment), params: {
      submission: {
        content: 'Submission with files',
        status: 'draft',
        files: [] # Empty array is acceptable for now
      }
    }
    
    submission = Submission.last
    assert_equal 'Submission with files', submission.content
    assert_redirected_to [@assignment, submission]
  end

  # Late Submission Tests
  test "should mark submission as late when submitted after due date" do
    @assignment.update!(due_date: 1.day.ago)
    
    sign_in @student
    
    post assignment_submissions_url(@assignment), params: {
      submission: {
        content: 'Late submission',
        status: 'submitted'
      }
    }
    
    submission = Submission.last
    assert submission.late?
    assert_redirected_to [@assignment, submission]
    assert_match 'Submission submitted (late)', flash[:notice]
  end

  # Statistics Tests
  test "should show submission statistics to teacher" do
    # Create various submission statuses
    User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    ).tap do |student2|
      Submission.create!(assignment: @assignment, user: student2, status: 'submitted')
    end
    
    User.create!(
      email: 'student3@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Three',
      role: 'student'
    ).tap do |student3|
      Submission.create!(assignment: @assignment, user: student3, status: 'graded', grade: 95)
    end
    
    sign_in @teacher
    get assignment_submissions_url(@assignment)
    assert_response :success
    assert_select '.submissions-stats'
    assert_select '.draft-count', text: /1/
    assert_select '.submitted-count', text: /1/
    assert_select '.graded-count', text: /1/
  end

  # JSON API Tests
  test "should respond to JSON requests" do
    sign_in @teacher
    
    get assignment_submissions_url(@assignment), headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should show submission in JSON format" do
    sign_in @student
    
    get assignment_submission_url(@assignment, @submission), headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @submission.status, json_response['status']
    assert_equal @assignment.id, json_response['assignment_id']
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end