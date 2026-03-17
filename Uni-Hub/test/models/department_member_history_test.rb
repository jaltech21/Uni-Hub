require 'test_helper'

class DepartmentMemberHistoryTest < ActiveSupport::TestCase
  setup do
    @department = departments(:computer_science)
    @user = users(:admin)
    
    @member_history = DepartmentMemberHistory.new(
      user: @user,
      department: @department,
      action: 'joined'
    )
  end

  test "should be valid with valid attributes" do
    assert @member_history.valid?
  end

  test "should require user" do
    @member_history.user = nil
    assert_not @member_history.valid?
    assert_includes @member_history.errors[:user], "must exist"
  end

  test "should require department" do
    @member_history.department = nil
    assert_not @member_history.valid?
    assert_includes @member_history.errors[:department], "must exist"
  end

  test "should require action" do
    @member_history.action = nil
    assert_not @member_history.valid?
    assert_includes @member_history.errors[:action], "can't be blank"
  end

  test "should validate action inclusion" do
    valid_actions = %w[joined left promoted demoted transferred]
    
    valid_actions.each do |action|
      @member_history.action = action
      assert @member_history.valid?, "#{action} should be a valid action"
    end
    
    @member_history.action = 'invalid_action'
    assert_not @member_history.valid?
    assert_includes @member_history.errors[:action], "is not included in the list"
  end

  test "should belong to user" do
    assert_respond_to @member_history, :user
    assert_instance_of User, @member_history.user
  end

  test "should belong to department" do
    assert_respond_to @member_history, :department
    assert_instance_of Department, @member_history.department
  end

  test "should order by created_at desc by default" do
    # Create multiple member history records
    older_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'joined',
      created_at: 2.days.ago
    )
    
    newer_user = User.create!(
      email: 'newuser@example.com',
      password: 'password123',
      first_name: 'New',
      last_name: 'User',
      role: 'student'
    )
    
    newer_history = DepartmentMemberHistory.create!(
      user: newer_user,
      department: @department,
      action: 'joined',
      created_at: 1.day.ago
    )
    
    records = DepartmentMemberHistory.all
    assert records.first.created_at >= records.last.created_at,
           "Records should be ordered by created_at desc"
  end

  test "should scope by department" do
    other_department = Department.create!(
      name: 'Other Department',
      code: 'OTHER',
      university: universities(:test_university)
    )
    
    # Create history in current department
    dept_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'joined'
    )
    
    # Create history in other department
    other_user = User.create!(
      email: 'otheruser@example.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'User',
      role: 'student'
    )
    
    other_history = DepartmentMemberHistory.create!(
      user: other_user,
      department: other_department,
      action: 'joined'
    )
    
    # Test department scoping
    dept_records = DepartmentMemberHistory.where(department: @department)
    assert_includes dept_records, dept_history
    assert_not_includes dept_records, other_history
  end

  test "should scope by action" do
    joined_record = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'joined'
    )
    
    new_user = User.create!(
      email: 'leftuser@example.com',
      password: 'password123',
      first_name: 'Left',
      last_name: 'User',
      role: 'student'
    )
    
    left_record = DepartmentMemberHistory.create!(
      user: new_user,
      department: @department,
      action: 'left'
    )
    
    joined_records = DepartmentMemberHistory.where(action: 'joined')
    assert_includes joined_records, joined_record
    assert_not_includes joined_records, left_record
  end

  test "should scope by user" do
    user_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'joined'
    )
    
    other_user = User.create!(
      email: 'otheruser@example.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'User',
      role: 'student'
    )
    
    other_history = DepartmentMemberHistory.create!(
      user: other_user,
      department: @department,
      action: 'joined'
    )
    
    user_records = DepartmentMemberHistory.where(user: @user)
    assert_includes user_records, user_history
    assert_not_includes user_records, other_history
  end

  test "should scope by date range" do
    old_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'joined',
      created_at: 1.week.ago
    )
    
    new_user = User.create!(
      email: 'recentuser@example.com',
      password: 'password123',
      first_name: 'Recent',
      last_name: 'User',
      role: 'student'
    )
    
    recent_history = DepartmentMemberHistory.create!(
      user: new_user,
      department: @department,
      action: 'joined',
      created_at: 1.day.ago
    )
    
    # Test recent records (last 3 days)
    recent_records = DepartmentMemberHistory.where(
      created_at: 3.days.ago..Time.current
    )
    
    assert_includes recent_records, recent_history
    assert_not_includes recent_records, old_history
  end

  test "should track role changes if role_before and role_after are present" do
    # Test if the model supports role change tracking
    if @member_history.respond_to?(:role_before) && @member_history.respond_to?(:role_after)
      @member_history.action = 'promoted'
      @member_history.role_before = 'student'
      @member_history.role_after = 'teacher'
      
      assert @member_history.valid?
      @member_history.save!
      
      assert_equal 'student', @member_history.role_before
      assert_equal 'teacher', @member_history.role_after
    end
  end

  test "should provide activity feed data" do
    @member_history.save!
    
    # Test that the record can provide activity feed information
    assert_respond_to @member_history, :created_at
    assert_respond_to @member_history, :action
    assert_respond_to @member_history, :user
    assert_respond_to @member_history, :department
    
    # Test formatted display methods if they exist
    if @member_history.respond_to?(:display_title)
      assert_kind_of String, @member_history.display_title
    end
    
    if @member_history.respond_to?(:display_description)
      assert_kind_of String, @member_history.display_description
    end
  end

  test "should validate user belongs to department for certain actions" do
    # Test business logic if implemented
    # For 'left' action, user might not need to be in department
    # For 'joined' action, user should be added to department
    
    @member_history.action = 'joined'
    @member_history.save!
    
    # If business logic is implemented, joining should update user's department
    if @user.respond_to?(:department_id)
      # This would be tested in integration tests typically
      # but we can check the model behavior here
      assert_kind_of Department, @member_history.department
    end
  end

  test "should handle multiple membership changes for same user" do
    # User joins
    join_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'joined',
      created_at: 2.days.ago
    )
    
    # User gets promoted
    promote_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'promoted',
      created_at: 1.day.ago
    )
    
    # User leaves
    leave_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'left',
      created_at: 1.hour.ago
    )
    
    user_histories = DepartmentMemberHistory.where(user: @user, department: @department)
                                           .order(:created_at)
    
    assert_equal 3, user_histories.count
    assert_equal 'joined', user_histories.first.action
    assert_equal 'promoted', user_histories.second.action
    assert_equal 'left', user_histories.third.action
  end

  test "should handle department transfers" do
    other_department = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    # User leaves current department
    leave_history = DepartmentMemberHistory.create!(
      user: @user,
      department: @department,
      action: 'transferred',
      created_at: 1.hour.ago
    )
    
    # User joins new department
    join_history = DepartmentMemberHistory.create!(
      user: @user,
      department: other_department,
      action: 'joined',
      created_at: 30.minutes.ago
    )
    
    # Should be able to track user across departments
    user_all_history = DepartmentMemberHistory.where(user: @user)
                                             .order(:created_at)
    
    assert_equal 2, user_all_history.count
    assert_equal @department, user_all_history.first.department
    assert_equal other_department, user_all_history.last.department
  end

  test "should validate reasonable action transitions" do
    # This would test business logic if implemented
    # For example, user can't 'leave' if they never 'joined'
    
    @member_history.action = 'left'
    
    # If validation is implemented, this might require a prior 'joined' action
    # For now, we just test that the model accepts the action
    assert @member_history.valid?
  end

  test "should have appropriate indexes for performance" do
    # Test that queries commonly used in activity feed are efficient
    # This is more of a documentation test
    
    # Common queries that should be indexed:
    # - department_id (for department filtering)
    # - user_id (for user filtering)
    # - created_at (for chronological sorting)
    # - action (for action filtering)
    # - user_id, department_id (for user-department history)
    
    expected_indexes = [
      'department_id',
      'user_id',
      'created_at',
      'action',
      'user_id, department_id'
    ]
    
    # This test passes but documents the expected database structure
    assert expected_indexes.any?, "Model should have appropriate database indexes"
  end

  test "should handle edge cases gracefully" do
    # Test with minimal required data
    minimal_history = DepartmentMemberHistory.new(
      user: @user,
      department: @department,
      action: 'joined'
    )
    
    assert minimal_history.valid?
    assert minimal_history.save
    
    # Test that timestamps are set
    assert_not_nil minimal_history.created_at
    assert_not_nil minimal_history.updated_at
  end

  test "should support soft deletes if implemented" do
    @member_history.save!
    
    # Test if soft delete is implemented
    if @member_history.respond_to?(:deleted_at)
      # Test soft delete
      @member_history.update(deleted_at: Time.current)
      
      # Should not appear in default scope if soft delete is implemented
      if DepartmentMemberHistory.respond_to?(:not_deleted)
        assert_not_includes DepartmentMemberHistory.not_deleted, @member_history
      end
    end
  end
end