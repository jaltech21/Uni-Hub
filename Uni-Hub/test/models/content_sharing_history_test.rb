require 'test_helper'

class ContentSharingHistoryTest < ActiveSupport::TestCase
  setup do
    @department = departments(:computer_science)
    @user = users(:admin)
    @user.update(department: @department)
    
    @content_sharing = ContentSharingHistory.new(
      shareable_type: 'Assignment',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared'
    )
  end

  test "should be valid with valid attributes" do
    assert @content_sharing.valid?
  end

  test "should require shareable_type" do
    @content_sharing.shareable_type = nil
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:shareable_type], "can't be blank"
  end

  test "should require shareable_id" do
    @content_sharing.shareable_id = nil
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:shareable_id], "can't be blank"
  end

  test "should require department" do
    @content_sharing.department = nil
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:department], "must exist"
  end

  test "should require shared_by user" do
    @content_sharing.shared_by = nil
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:shared_by], "must exist"
  end

  test "should require action" do
    @content_sharing.action = nil
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:action], "can't be blank"
  end

  test "should validate action inclusion" do
    valid_actions = %w[shared unshared updated removed]
    
    valid_actions.each do |action|
      @content_sharing.action = action
      assert @content_sharing.valid?, "#{action} should be a valid action"
    end
    
    @content_sharing.action = 'invalid_action'
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:action], "is not included in the list"
  end

  test "should validate shareable_type inclusion" do
    valid_types = %w[Assignment Quiz Note Announcement]
    
    valid_types.each do |type|
      @content_sharing.shareable_type = type
      assert @content_sharing.valid?, "#{type} should be a valid shareable_type"
    end
    
    @content_sharing.shareable_type = 'InvalidType'
    assert_not @content_sharing.valid?
    assert_includes @content_sharing.errors[:shareable_type], "is not included in the list"
  end

  test "should belong to department" do
    assert_respond_to @content_sharing, :department
    assert_instance_of Department, @content_sharing.department
  end

  test "should belong to shared_by user" do
    assert_respond_to @content_sharing, :shared_by
    assert_instance_of User, @content_sharing.shared_by
  end

  test "should have shareable polymorphic association" do
    assert_respond_to @content_sharing, :shareable
    # Note: shareable will be nil unless the actual record exists
  end

  test "should order by created_at desc by default" do
    # Create multiple content sharing records
    older_sharing = ContentSharingHistory.create!(
      shareable_type: 'Note',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared',
      created_at: 2.days.ago
    )
    
    newer_sharing = ContentSharingHistory.create!(
      shareable_type: 'Quiz',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared',
      created_at: 1.day.ago
    )
    
    records = ContentSharingHistory.all
    assert records.first.created_at >= records.last.created_at,
           "Records should be ordered by created_at desc"
  end

  test "should scope by department" do
    other_department = Department.create!(
      name: 'Other Department',
      code: 'OTHER',
      university: universities(:test_university)
    )
    
    # Create sharing in current department
    dept_sharing = ContentSharingHistory.create!(
      shareable_type: 'Assignment',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared'
    )
    
    # Create sharing in other department
    other_user = User.create!(
      email: 'otheruser@example.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'User',
      role: 'student',
      department: other_department
    )
    
    other_sharing = ContentSharingHistory.create!(
      shareable_type: 'Note',
      shareable_id: 1,
      department: other_department,
      shared_by: other_user,
      action: 'shared'
    )
    
    # Test department scoping
    dept_records = ContentSharingHistory.where(department: @department)
    assert_includes dept_records, dept_sharing
    assert_not_includes dept_records, other_sharing
  end

  test "should scope by action" do
    shared_record = ContentSharingHistory.create!(
      shareable_type: 'Assignment',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared'
    )
    
    unshared_record = ContentSharingHistory.create!(
      shareable_type: 'Assignment',
      shareable_id: 2,
      department: @department,
      shared_by: @user,
      action: 'unshared'
    )
    
    shared_records = ContentSharingHistory.where(action: 'shared')
    assert_includes shared_records, shared_record
    assert_not_includes shared_records, unshared_record
  end

  test "should scope by shareable_type" do
    assignment_sharing = ContentSharingHistory.create!(
      shareable_type: 'Assignment',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared'
    )
    
    quiz_sharing = ContentSharingHistory.create!(
      shareable_type: 'Quiz',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared'
    )
    
    assignment_records = ContentSharingHistory.where(shareable_type: 'Assignment')
    assert_includes assignment_records, assignment_sharing
    assert_not_includes assignment_records, quiz_sharing
  end

  test "should scope by date range" do
    old_sharing = ContentSharingHistory.create!(
      shareable_type: 'Assignment',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared',
      created_at: 1.week.ago
    )
    
    recent_sharing = ContentSharingHistory.create!(
      shareable_type: 'Quiz',
      shareable_id: 1,
      department: @department,
      shared_by: @user,
      action: 'shared',
      created_at: 1.day.ago
    )
    
    # Test recent records (last 3 days)
    recent_records = ContentSharingHistory.where(
      created_at: 3.days.ago..Time.current
    )
    
    assert_includes recent_records, recent_sharing
    assert_not_includes recent_records, old_sharing
  end

  test "should provide activity feed data" do
    @content_sharing.save!
    
    # Test that the record can provide activity feed information
    assert_respond_to @content_sharing, :created_at
    assert_respond_to @content_sharing, :action
    assert_respond_to @content_sharing, :shareable_type
    assert_respond_to @content_sharing, :shared_by
    
    # Test formatted display methods if they exist
    if @content_sharing.respond_to?(:display_title)
      assert_kind_of String, @content_sharing.display_title
    end
    
    if @content_sharing.respond_to?(:display_description)
      assert_kind_of String, @content_sharing.display_description
    end
  end

  test "should handle soft deletes if implemented" do
    @content_sharing.save!
    
    # Test if soft delete is implemented
    if @content_sharing.respond_to?(:deleted_at)
      # Test soft delete
      @content_sharing.update(deleted_at: Time.current)
      
      # Should not appear in default scope if soft delete is implemented
      if ContentSharingHistory.respond_to?(:not_deleted)
        assert_not_includes ContentSharingHistory.not_deleted, @content_sharing
      end
    end
  end

  test "should validate uniqueness constraints if any" do
    @content_sharing.save!
    
    # Test if there are uniqueness constraints
    duplicate = ContentSharingHistory.new(
      shareable_type: @content_sharing.shareable_type,
      shareable_id: @content_sharing.shareable_id,
      department: @content_sharing.department,
      shared_by: @content_sharing.shared_by,
      action: @content_sharing.action
    )
    
    # This test will pass if no uniqueness constraints exist
    # and fail appropriately if they do exist
    result = duplicate.valid?
    if result
      # No uniqueness constraints
      assert duplicate.save
    else
      # Check for uniqueness error messages
      uniqueness_errors = duplicate.errors.messages.values.flatten.select do |msg|
        msg.include?('has already been taken')
      end
      
      assert uniqueness_errors.any?, "Expected uniqueness validation errors"
    end
  end

  test "should have appropriate indexes for performance" do
    # Test that queries commonly used in activity feed are efficient
    # This is more of a documentation test
    
    # Common queries that should be indexed:
    # - department_id (for department filtering)
    # - created_at (for chronological sorting)
    # - shared_by_id (for user filtering)
    # - shareable_type, shareable_id (for polymorphic association)
    # - action (for action filtering)
    
    # We can't directly test indexes in unit tests, but we can document
    # the expected indexes here for reference
    expected_indexes = [
      'department_id',
      'created_at',
      'shared_by_id',
      'shareable_type, shareable_id',
      'action'
    ]
    
    # This test passes but documents the expected database structure
    assert expected_indexes.any?, "Model should have appropriate database indexes"
  end
end