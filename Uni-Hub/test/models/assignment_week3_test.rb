require 'test_helper'

class AssignmentTest < ActiveSupport::TestCase
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @department = departments(:computer_science)
    @assignment = Assignment.new(
      title: 'Test Assignment',
      description: 'This is a test assignment',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
  end

  test "should be valid with valid attributes" do
    assert @assignment.valid?
  end

  test "should require title" do
    @assignment.title = nil
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:title], "can't be blank"
  end

  test "should require description" do
    @assignment.description = nil
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:description], "can't be blank"
  end

  test "should require due_date" do
    @assignment.due_date = nil
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:due_date], "can't be blank"
  end

  test "should require valid category" do
    @assignment.category = 'invalid_category'
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:category], "invalid_category is not a valid category"
  end

  test "should validate points numericality" do
    @assignment.points = -10
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:points], "must be greater than or equal to 0"
  end

  test "should belong to user" do
    assert_respond_to @assignment, :user
    assert_instance_of User, @assignment.user
  end

  test "should belong to department" do
    assert_respond_to @assignment, :department
    assert_instance_of Department, @assignment.department
  end

  test "should have many submissions" do
    @assignment.save!
    submission = @assignment.submissions.create!(user: @student, status: 'submitted')
    assert_includes @assignment.submissions, submission
  end

  test "should check if overdue" do
    @assignment.due_date = 1.day.ago
    @assignment.save!
    assert @assignment.overdue?
    
    @assignment.due_date = 1.day.from_now
    assert_not @assignment.overdue?
  end

  test "should count submitted assignments" do
    @assignment.save!
    
    # Create submitted submission
    @assignment.submissions.create!(
      user: @student,
      status: 'submitted',
      submitted_at: Time.current
    )
    
    assert_equal 1, @assignment.submitted_count
  end

  test "should count graded assignments" do
    @assignment.save!
    
    # Create graded submission
    @assignment.submissions.create!(
      user: @student,
      status: 'graded',
      grade: 85,
      graded_at: Time.current,
      graded_by: @teacher
    )
    
    assert_equal 1, @assignment.graded_count
  end

  test "should calculate average grade" do
    @assignment.save!
    
    # Create submissions with grades
    @assignment.submissions.create!(
      user: @student,
      status: 'graded',
      grade: 80
    )
    
    another_student = User.create!(
      email: 'student2@test.com',
      password: 'password123',
      first_name: 'Student',
      last_name: 'Two',
      role: 'student'
    )
    
    @assignment.submissions.create!(
      user: another_student,
      status: 'graded',
      grade: 90
    )
    
    assert_equal 85.0, @assignment.average_grade
  end

  test "should filter by category" do
    homework = Assignment.create!(
      title: 'Homework 1',
      description: 'Test homework',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 50,
      category: 'homework'
    )
    
    project = Assignment.create!(
      title: 'Project 1',
      description: 'Test project',
      due_date: 2.weeks.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'project'
    )
    
    homework_assignments = Assignment.by_category('homework')
    project_assignments = Assignment.by_category('project')
    
    assert_includes homework_assignments, homework
    assert_not_includes homework_assignments, project
    assert_includes project_assignments, project
    assert_not_includes project_assignments, homework
  end

  test "should filter by department" do
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    cs_assignment = Assignment.create!(
      title: 'CS Assignment',
      description: 'Computer Science assignment',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
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
    
    cs_assignments = Assignment.by_department(@department)
    physics_assignments = Assignment.by_department(physics_dept)
    
    assert_includes cs_assignments, cs_assignment
    assert_not_includes cs_assignments, physics_assignment
    assert_includes physics_assignments, physics_assignment
    assert_not_includes physics_assignments, cs_assignment
  end

  test "should scope upcoming assignments" do
    past_assignment = Assignment.create!(
      title: 'Past Assignment',
      description: 'This assignment is overdue',
      due_date: 1.week.ago,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
    
    future_assignment = Assignment.create!(
      title: 'Future Assignment',
      description: 'This assignment is upcoming',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
    
    upcoming = Assignment.upcoming
    
    assert_includes upcoming, future_assignment
    assert_not_includes upcoming, past_assignment
  end

  test "should scope overdue assignments" do
    past_assignment = Assignment.create!(
      title: 'Past Assignment',
      description: 'This assignment is overdue',
      due_date: 1.week.ago,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
    
    future_assignment = Assignment.create!(
      title: 'Future Assignment',
      description: 'This assignment is upcoming',
      due_date: 1.week.from_now,
      user: @teacher,
      department: @department,
      points: 100,
      category: 'homework'
    )
    
    overdue = Assignment.overdue
    
    assert_includes overdue, past_assignment
    assert_not_includes overdue, future_assignment
  end

  test "should handle multiple department assignments" do
    @assignment.save!
    
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    # Assign to additional department
    @assignment.assign_to_departments(physics_dept)
    
    assert_includes @assignment.all_departments, @department
    assert_includes @assignment.all_departments, physics_dept
    assert @assignment.available_to_department?(physics_dept)
  end

  test "should have file attachments" do
    assert_respond_to @assignment, :files
    # Active Storage attachments are tested separately
  end

  test "should cascade delete submissions when assignment is deleted" do
    @assignment.save!
    submission = @assignment.submissions.create!(user: @student, status: 'submitted')
    
    assert_difference 'Submission.count', -1 do
      @assignment.destroy
    end
  end

  test "should validate title length" do
    @assignment.title = 'A' * 256  # Too long
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:title], "is too long (maximum is 255 characters)"
    
    @assignment.title = 'AB'  # Too short
    assert_not @assignment.valid?
    assert_includes @assignment.errors[:title], "is too short (minimum is 3 characters)"
  end

  test "should return zero counts when no submissions exist" do
    @assignment.save!
    
    assert_equal 0, @assignment.submitted_count
    assert_equal 0, @assignment.graded_count
    assert_equal 0, @assignment.pending_submissions_count
    assert_equal 0, @assignment.average_grade
  end
end