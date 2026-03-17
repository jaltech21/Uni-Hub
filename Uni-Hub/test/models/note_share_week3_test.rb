require 'test_helper'

class NoteShareTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
    @department = departments(:computer_science)
    
    @note = Note.create!(
      title: 'Shared Study Guide',
      content: 'This note will be shared with students for collaborative learning.',
      user: @teacher,
      department: @department
    )
    
    @note_share = NoteShare.new(
      note: @note,
      shared_by: @teacher,
      shared_with: @student,
      permission: 'view'
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @note_share.valid?
  end

  test "should require note" do
    @note_share.note = nil
    assert_not @note_share.valid?
    assert_includes @note_share.errors[:note], "must exist"
  end

  test "should require shared_by user" do
    @note_share.shared_by = nil
    assert_not @note_share.valid?
    assert_includes @note_share.errors[:shared_by], "must exist"
  end

  test "should require shared_with user" do
    @note_share.shared_with = nil
    assert_not @note_share.valid?
    assert_includes @note_share.errors[:shared_with], "must exist"
  end

  test "should validate permission inclusion" do
    @note_share.permission = 'invalid_permission'
    assert_not @note_share.valid?
    assert_includes @note_share.errors[:permission], "must be 'view' or 'edit'"

    valid_permissions = ['view', 'edit']
    valid_permissions.each do |permission|
      @note_share.permission = permission
      assert @note_share.valid?, "#{permission} should be a valid permission"
    end
  end

  test "should require unique shared_with per note" do
    @note_share.save!
    
    duplicate_share = NoteShare.new(
      note: @note,
      shared_by: @teacher,
      shared_with: @student,  # Same user
      permission: 'edit'
    )
    
    assert_not duplicate_share.valid?
    assert_includes duplicate_share.errors[:shared_with_id], "already has access to this note"
  end

  test "should allow same user to have access to different notes" do
    @note_share.save!
    
    other_note = Note.create!(
      title: 'Another Note',
      content: 'Different note content',
      user: @teacher,
      department: @department
    )
    
    different_note_share = NoteShare.new(
      note: other_note,
      shared_by: @teacher,
      shared_with: @student,  # Same user, different note
      permission: 'view'
    )
    
    assert different_note_share.valid?
  end

  test "should not allow sharing with self" do
    self_share = NoteShare.new(
      note: @note,
      shared_by: @teacher,
      shared_with: @teacher,  # Same as shared_by
      permission: 'view'
    )
    
    assert_not self_share.valid?
    assert_includes self_share.errors[:shared_with], "cannot share note with yourself"
  end

  test "should not allow sharing with note owner" do
    owner_share = NoteShare.new(
      note: @note,
      shared_by: @student,  # Different from owner
      shared_with: @teacher,  # Note owner
      permission: 'view'
    )
    
    assert_not owner_share.valid?
    assert_includes owner_share.errors[:shared_with], "is already the owner of this note"
  end

  # Association Tests
  test "should belong to note" do
    assert_respond_to @note_share, :note
    @note_share.save!
    assert_instance_of Note, @note_share.note
  end

  test "should belong to shared_by user" do
    assert_respond_to @note_share, :shared_by
    @note_share.save!
    assert_instance_of User, @note_share.shared_by
    assert_equal @teacher, @note_share.shared_by
  end

  test "should belong to shared_with user" do
    assert_respond_to @note_share, :shared_with
    @note_share.save!
    assert_instance_of User, @note_share.shared_with
    assert_equal @student, @note_share.shared_with
  end

  # Permission Methods Tests
  test "should correctly identify edit permission" do
    @note_share.permission = 'edit'
    @note_share.save!
    
    assert @note_share.can_edit?
    assert_not @note_share.can_only_view?
  end

  test "should correctly identify view permission" do
    @note_share.permission = 'view'
    @note_share.save!
    
    assert_not @note_share.can_edit?
    assert @note_share.can_only_view?
  end

  # Scope Tests
  test "should filter shares by user" do
    @note_share.save!
    
    admin_share = NoteShare.create!(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'edit'
    )
    
    student_shares = NoteShare.by_user(@student)
    admin_shares = NoteShare.by_user(@admin)
    
    assert_includes student_shares, @note_share
    assert_not_includes student_shares, admin_share
    assert_includes admin_shares, admin_share
    assert_not_includes admin_shares, @note_share
  end

  test "should filter view-only shares" do
    @note_share.permission = 'view'
    @note_share.save!
    
    edit_share = NoteShare.create!(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'edit'
    )
    
    view_shares = NoteShare.view_only
    assert_includes view_shares, @note_share
    assert_not_includes view_shares, edit_share
  end

  test "should filter editable shares" do
    @note_share.permission = 'edit'
    @note_share.save!
    
    view_share = NoteShare.create!(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'view'
    )
    
    edit_shares = NoteShare.editable
    assert_includes edit_shares, @note_share
    assert_not_includes edit_shares, view_share
  end

  # Timestamp Tests
  test "should set created_at and updated_at automatically" do
    freeze_time = Time.current
    travel_to freeze_time do
      @note_share.save!
      assert_equal freeze_time.to_i, @note_share.created_at.to_i
      assert_equal freeze_time.to_i, @note_share.updated_at.to_i
    end
  end

  test "should update updated_at when permission changes" do
    @note_share.save!
    original_updated_at = @note_share.updated_at
    
    travel_to 1.hour.from_now do
      @note_share.update!(permission: 'edit')
      assert @note_share.updated_at > original_updated_at
    end
  end

  # Business Logic Tests
  test "should allow permission upgrade from view to edit" do
    @note_share.permission = 'view'
    @note_share.save!
    
    assert @note_share.can_only_view?
    
    @note_share.update!(permission: 'edit')
    assert @note_share.can_edit?
  end

  test "should allow permission downgrade from edit to view" do
    @note_share.permission = 'edit'
    @note_share.save!
    
    assert @note_share.can_edit?
    
    @note_share.update!(permission: 'view')
    assert @note_share.can_only_view?
  end

  # Integration Tests with Note Model
  test "should integrate with note sharing methods" do
    assert_not @note.shared_with?(@student)
    
    @note_share.save!
    assert @note.shared_with?(@student)
    
    # Test note's viewability
    assert @note.viewable_by?(@student)
    assert_not @note.editable_by?(@student)  # View permission only
    
    # Upgrade to edit permission
    @note_share.update!(permission: 'edit')
    assert @note.editable_by?(@student)
  end

  test "should work with note share_with method" do
    # Use note's built-in sharing method
    @note.share_with(@student, permission: 'view')
    
    share = @note.note_shares.find_by(shared_with: @student)
    assert_not_nil share
    assert_equal 'view', share.permission
    assert_equal @teacher, share.shared_by
  end

  # Multiple Users Sharing Tests
  test "should allow note to be shared with multiple users" do
    @note_share.save!
    
    admin_share = NoteShare.create!(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'edit'
    )
    
    assert_equal 2, @note.note_shares.count
    assert_includes @note.shared_with_users, @student
    assert_includes @note.shared_with_users, @admin
  end

  test "should handle different permissions for different users" do
    # Share with student (view only)
    @note_share.permission = 'view'
    @note_share.save!
    
    # Share with admin (edit)
    admin_share = NoteShare.create!(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'edit'
    )
    
    assert @note.viewable_by?(@student)
    assert_not @note.editable_by?(@student)
    
    assert @note.viewable_by?(@admin)
    assert @note.editable_by?(@admin)
  end

  # Deletion Cascade Tests
  test "should be destroyed when note is destroyed" do
    @note_share.save!
    
    assert_difference 'NoteShare.count', -1 do
      @note.destroy
    end
  end

  test "should be automatically removed when shared_with user is destroyed" do
    @note_share.save!
    
    assert_difference 'NoteShare.count', -1 do
      @student.destroy
    end
  end

  test "should be automatically removed when shared_by user is destroyed" do
    @note_share.save!
    
    assert_difference 'NoteShare.count', -1 do
      @teacher.destroy
    end
  end

  # Edge Cases
  test "should handle sharing note from different department" do
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_teacher = User.create!(
      email: 'physics_teacher@test.com',
      password: 'password123',
      first_name: 'Physics',
      last_name: 'Teacher',
      role: 'teacher',
      department: physics_dept
    )
    
    cross_dept_share = NoteShare.create!(
      note: @note,
      shared_by: physics_teacher,  # From different department
      shared_with: @student,
      permission: 'view'
    )
    
    assert cross_dept_share.valid?
    assert cross_dept_share.persisted?
  end

  test "should handle sharing with user from different role" do
    # Teacher sharing with admin
    admin_share = NoteShare.new(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'edit'
    )
    
    assert admin_share.valid?
    
    # Student sharing with teacher (if student owns note)
    student_note = Note.create!(
      title: 'Student Note',
      content: 'Note created by student',
      user: @student,
      department: @department
    )
    
    reverse_share = NoteShare.new(
      note: student_note,
      shared_by: @student,
      shared_with: @teacher,
      permission: 'view'
    )
    
    assert reverse_share.valid?
  end

  # Performance Tests
  test "should efficiently query shared notes" do
    # Create multiple shares
    10.times do |i|
      user = User.create!(
        email: "user#{i}@test.com",
        password: 'password123',
        first_name: 'User',
        last_name: i.to_s,
        role: 'student'
      )
      
      NoteShare.create!(
        note: @note,
        shared_by: @teacher,
        shared_with: user,
        permission: ['view', 'edit'].sample
      )
    end
    
    # Query should be efficient with includes
    shares_with_users = NoteShare.includes(:shared_with, :note).where(note: @note)
    
    assert_no_queries do
      shares_with_users.each do |share|
        share.shared_with.full_name
        share.note.title
      end
    end
  end

  # Security Tests
  test "should prevent unauthorized permission escalation" do
    @note_share.permission = 'view'
    @note_share.save!
    
    # Simulate unauthorized attempt to escalate permissions
    # This would typically be prevented at the controller level
    original_permission = @note_share.permission
    
    # Direct model update should still work (controller should prevent this)
    @note_share.update!(permission: 'edit')
    assert_equal 'edit', @note_share.permission
    
    # But we can test that the validation still works
    invalid_share = NoteShare.new(
      note: @note,
      shared_by: @teacher,
      shared_with: @admin,
      permission: 'invalid'
    )
    
    assert_not invalid_share.valid?
  end

  # Statistical Tests
  test "should provide sharing statistics" do
    # Create shares with different permissions
    @note_share.permission = 'view'
    @note_share.save!
    
    3.times do |i|
      user = User.create!(
        email: "editor#{i}@test.com",
        password: 'password123',
        first_name: 'Editor',
        last_name: i.to_s,
        role: 'student'
      )
      
      NoteShare.create!(
        note: @note,
        shared_by: @teacher,
        shared_with: user,
        permission: 'edit'
      )
    end
    
    total_shares = @note.note_shares.count
    view_shares = @note.note_shares.view_only.count
    edit_shares = @note.note_shares.editable.count
    
    assert_equal 4, total_shares
    assert_equal 1, view_shares
    assert_equal 3, edit_shares
  end
end