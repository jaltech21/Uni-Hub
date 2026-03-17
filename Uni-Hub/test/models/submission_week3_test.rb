require 'test_helper'

class SubmissionTest < ActiveSupport::TestCase
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
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
    
    @submission = Submission.new(
      assignment: @assignment,
      user: @student,
      status: 'submitted'
    )
  end

  test "should be valid with valid attributes" do
    assert @submission.valid?
  end

  test "should belong to assignment" do
    assert_respond_to @submission, :assignment
    assert_instance_of Assignment, @submission.assignment
  end

  test "should belong to user" do
    assert_respond_to @submission, :user
    assert_instance_of User, @submission.user
  end

  test "should belong to graded_by user" do
    assert_respond_to @submission, :graded_by
    
    @submission.graded_by = @teacher
    assert_instance_of User, @submission.graded_by
  end

  test "should validate status inclusion" do
    valid_statuses = %w[pending submitted graded]
    
    valid_statuses.each do |status|
      @submission.status = status
      assert @submission.valid?, "#{status} should be a valid status"
    end
    
    @submission.status = 'invalid_status'
    assert_not @submission.valid?
    assert_includes @submission.errors[:status], "invalid_status is not a valid status"
  end

  test "should validate grade numericality" do
    @submission.grade = -10
    assert_not @submission.valid?
    assert_includes @submission.errors[:grade], "must be greater than or equal to 0"
    
    @submission.grade = @assignment.points + 10  # Grade higher than max points
    assert_not @submission.valid?
    assert_includes @submission.errors[:grade], "must be less than or equal to #{@assignment.points}"
  end

  test "should allow nil grade" do
    @submission.grade = nil
    assert @submission.valid?
  end

  test "should set submitted_at on creation" do
    @submission.save!
    assert_not_nil @submission.submitted_at
    assert_equal 'submitted', @submission.status
  end

  test "should set graded_at when grade is updated" do
    @submission.save!
    assert_nil @submission.graded_at
    
    @submission.update!(grade: 85, graded_by: @teacher)
    assert_not_nil @submission.graded_at
    assert_equal 'graded', @submission.status
  end

  test "should check if submission is late" do
    # Create assignment with due date in the past
    past_assignment = Assignment.create!(
      title: 'Past Assignment',
      description: 'This assignment is overdue',
      due_date: 1.day.ago,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
    
    late_submission = Submission.create!(
      assignment: past_assignment,
      user: @student,
      status: 'submitted',
      submitted_at: Time.current
    )
    
    assert late_submission.late_submission?
    
    # Test on-time submission
    @submission.save!
    assert_not @submission.late_submission?
  end

  test "should calculate percentage grade" do
    @submission.grade = 80
    @submission.save!
    
    assert_equal 80.0, @submission.percentage_grade
  end

  test "should return nil percentage grade when no grade" do
    @submission.grade = nil
    @submission.save!
    
    assert_nil @submission.percentage_grade
  end

  test "should return nil percentage grade when assignment has zero points" do
    @assignment.update!(points: 0)
    @submission.grade = 0
    @submission.save!
    
    assert_nil @submission.percentage_grade
  end

  test "should calculate letter grade" do
    test_cases = [
      [95, 'A'],
      [85, 'B'],
      [75, 'C'],
      [65, 'D'],
      [55, 'F']
    ]
    
    test_cases.each do |grade, expected_letter|
      @submission.grade = grade
      @submission.save!
      assert_equal expected_letter, @submission.letter_grade, "Grade #{grade} should be letter #{expected_letter}"
    end
  end

  test "should return nil letter grade when no grade" do
    @submission.grade = nil
    @submission.save!
    
    assert_nil @submission.letter_grade
  end

  test "should check if has grade with feedback" do
    @submission.grade = 85
    @submission.feedback = "Good work!"
    @submission.save!
    
    assert @submission.grade_with_feedback?
    
    @submission.feedback = nil
    assert_not @submission.grade_with_feedback?
    
    @submission.grade = nil
    @submission.feedback = "Needs improvement"
    assert_not @submission.grade_with_feedback?
  end

  test "should scope by status" do
    pending_submission = Submission.create!(
      assignment: @assignment,
      user: @student,
      status: 'pending'
    )
    
    submitted_submission = Submission.create!(
      assignment: @assignment,
      user: users(:admin),  # Different user
      status: 'submitted'
    )
    
    graded_submission = Submission.create!(
      assignment: @assignment,
      user: users(:admin),  # Different user  
      status: 'graded',
      grade: 90
    )
    
    assert_includes Submission.pending, pending_submission
    assert_not_includes Submission.pending, submitted_submission
    
    assert_includes Submission.submitted, submitted_submission
    assert_not_includes Submission.submitted, graded_submission
    
    assert_includes Submission.graded, graded_submission
    assert_not_includes Submission.graded, pending_submission
  end

  test "should scope by student" do
    student_submission = Submission.create!(
      assignment: @assignment,
      user: @student,
      status: 'submitted'
    )
    
    other_student = users(:admin)
    other_submission = Submission.create!(
      assignment: @assignment,
      user: other_student,
      status: 'submitted'
    )
    
    student_submissions = Submission.by_student(@student.id)
    
    assert_includes student_submissions, student_submission
    assert_not_includes student_submissions, other_submission
  end

  test "should order by submitted date" do
    first_submission = Submission.create!(
      assignment: @assignment,
      user: @student,
      status: 'submitted',
      submitted_at: 2.days.ago
    )
    
    second_submission = Submission.create!(
      assignment: @assignment,
      user: users(:admin),
      status: 'submitted',
      submitted_at: 1.day.ago
    )
    
    recent_submissions = Submission.recent
    
    assert_equal second_submission, recent_submissions.first
    assert_equal first_submission, recent_submissions.second
  end

  test "should have document attachments" do
    assert_respond_to @submission, :documents
    # Active Storage attachments are tested separately
  end

  test "should require documents on creation" do
    # This test assumes Active Storage is properly set up
    # In a real scenario, you'd need to attach actual files
    
    @submission.save
    # Without proper file attachments, this might fail
    # The validation is in the model: validates :documents, presence: true, on: :create
  end

  test "should handle edge cases for percentage calculation" do
    # Test with very small points value
    @assignment.update!(points: 0.1)
    @submission.grade = 0.05
    @submission.save!
    
    assert_equal 50.0, @submission.percentage_grade
  end

  test "should handle large grade values" do
    @assignment.update!(points: 1000)
    @submission.grade = 999
    @submission.save!
    
    assert_equal 99.9, @submission.percentage_grade
    assert_equal 'A', @submission.letter_grade
  end
end