require 'test_helper'

class NoteTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
    @department = departments(:computer_science)
    
    @note = Note.new(
      title: 'Advanced Algorithms Study Guide',
      content: 'Comprehensive notes on sorting algorithms and their complexities.',
      user: @teacher,
      department: @department,
      visibility: 'private',
      note_type: 'study_guide'
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @note.valid?
  end

  test "should require title" do
    @note.title = nil
    assert_not @note.valid?
    assert_includes @note.errors[:title], "can't be blank"

    @note.title = ""
    assert_not @note.valid?
    assert_includes @note.errors[:title], "can't be blank"
  end

  test "should require content" do
    @note.content = nil
    assert_not @note.valid?
    assert_includes @note.errors[:content], "can't be blank"

    @note.content = ""
    assert_not @note.valid?
    assert_includes @note.errors[:content], "can't be blank"
  end

  test "should require user" do
    @note.user = nil
    assert_not @note.valid?
    assert_includes @note.errors[:user], "must exist"
  end

  test "should require department" do
    @note.department = nil
    assert_not @note.valid?
    assert_includes @note.errors[:department], "must exist"
  end

  test "should require visibility" do
    @note.visibility = nil
    assert_not @note.valid?
    assert_includes @note.errors[:visibility], "can't be blank"

    @note.visibility = ""
    assert_not @note.valid?
    assert_includes @note.errors[:visibility], "can't be blank"
  end

  test "should validate visibility inclusion" do
    @note.visibility = 'invalid_visibility'
    assert_not @note.valid?
    assert_includes @note.errors[:visibility], "is not included in the list"

    valid_visibilities = ['private', 'department', 'public']
    valid_visibilities.each do |visibility|
      @note.visibility = visibility
      assert @note.valid?, "#{visibility} should be a valid visibility"
    end
  end

  test "should validate note_type inclusion" do
    @note.note_type = 'invalid_type'
    assert_not @note.valid?
    assert_includes @note.errors[:note_type], "is not included in the list"

    valid_types = ['lecture', 'study_guide', 'assignment', 'meeting', 'personal', 'research']
    valid_types.each do |type|
      @note.note_type = type
      assert @note.valid?, "#{type} should be a valid note type"
    end
  end

  test "should validate title length" do
    @note.title = "a" * 201  # Assuming max length is 200
    assert_not @note.valid?
    assert_includes @note.errors[:title], "is too long (maximum is 200 characters)"
  end

  test "should validate content has reasonable minimum length" do
    @note.content = "ab"  # Too short
    assert_not @note.valid?
    assert_includes @note.errors[:content], "is too short (minimum is 3 characters)"
  end

  # Association Tests
  test "should belong to user" do
    assert_respond_to @note, :user
    @note.save!
    assert_instance_of User, @note.user
  end

  test "should belong to department" do
    assert_respond_to @note, :department
    @note.save!
    assert_instance_of Department, @note.department
  end

  test "should have many note shares" do
    assert_respond_to @note, :note_shares
    @note.save!
    
    @note.note_shares.create!(user: @student, permission: 'read')
    
    assert_equal 1, @note.note_shares.count
    assert_instance_of NoteShare, @note.note_shares.first
  end

  test "should have many shared_users through note_shares" do
    assert_respond_to @note, :shared_users
    @note.save!
    
    @note.note_shares.create!(user: @student, permission: 'read')
    @note.note_shares.create!(user: @admin, permission: 'edit')
    
    assert_equal 2, @note.shared_users.count
    assert_includes @note.shared_users, @student
    assert_includes @note.shared_users, @admin
  end

  test "should have many note tags" do
    assert_respond_to @note, :note_tags
    @note.save!
    
    @note.note_tags.create!(name: 'algorithms')
    @note.note_tags.create!(name: 'sorting')
    
    assert_equal 2, @note.note_tags.count
    assert_instance_of NoteTag, @note.note_tags.first
  end

  test "should destroy dependent associations" do
    @note.save!
    @note.note_shares.create!(user: @student, permission: 'read')
    @note.note_tags.create!(name: 'test-tag')
    
    assert_difference 'NoteShare.count', -1 do
      assert_difference 'NoteTag.count', -1 do
        @note.destroy
      end
    end
  end

  # Visibility Logic Tests
  test "should correctly identify private notes" do
    @note.visibility = 'private'
    @note.save!
    
    assert @note.private?
    assert_not @note.department_visible?
    assert_not @note.public?
  end

  test "should correctly identify department visible notes" do
    @note.visibility = 'department'
    @note.save!
    
    assert_not @note.private?
    assert @note.department_visible?
    assert_not @note.public?
  end

  test "should correctly identify public notes" do
    @note.visibility = 'public'
    @note.save!
    
    assert_not @note.private?
    assert_not @note.department_visible?
    assert @note.public?
  end

  # Permission System Tests
  test "should allow owner to read their notes" do
    @note.save!
    assert @note.can_read?(@teacher)
  end

  test "should allow owner to edit their notes" do
    @note.save!
    assert @note.can_edit?(@teacher)
  end

  test "should allow owner to delete their notes" do
    @note.save!
    assert @note.can_delete?(@teacher)
  end

  test "should not allow non-owner to access private notes" do
    @note.visibility = 'private'
    @note.save!
    
    assert_not @note.can_read?(@student)
    assert_not @note.can_edit?(@student)
    assert_not @note.can_delete?(@student)
  end

  test "should allow department members to read department notes" do
    @note.visibility = 'department'
    @note.save!
    
    # Assuming student is in same department
    assert @note.can_read?(@student)
    assert_not @note.can_edit?(@student)  # Only shared users can edit
    assert_not @note.can_delete?(@student)
  end

  test "should allow everyone to read public notes" do
    @note.visibility = 'public'
    @note.save!
    
    other_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_student = User.create!(
      email: 'physics@test.com',
      password: 'password123',
      first_name: 'Physics',
      last_name: 'Student',
      role: 'student',
      department: other_dept
    )
    
    assert @note.can_read?(physics_student)
    assert_not @note.can_edit?(physics_student)
    assert_not @note.can_delete?(physics_student)
  end

  test "should respect shared user permissions" do
    @note.save!
    
    # Share with read permission
    @note.note_shares.create!(user: @student, permission: 'read')
    assert @note.can_read?(@student)
    assert_not @note.can_edit?(@student)
    assert_not @note.can_delete?(@student)
    
    # Update to edit permission
    @note.note_shares.find_by(user: @student).update!(permission: 'edit')
    assert @note.can_read?(@student)
    assert @note.can_edit?(@student)
    assert_not @note.can_delete?(@student)  # Only owner can delete
  end

  # Sharing Methods Tests
  test "should share note with user" do
    @note.save!
    
    @note.share_with(@student, 'read')
    
    assert_equal 1, @note.note_shares.count
    share = @note.note_shares.first
    assert_equal @student, share.user
    assert_equal 'read', share.permission
  end

  test "should update existing share permission" do
    @note.save!
    @note.share_with(@student, 'read')
    
    # Update permission
    @note.share_with(@student, 'edit')
    
    assert_equal 1, @note.note_shares.count
    share = @note.note_shares.first
    assert_equal 'edit', share.permission
  end

  test "should unshare note with user" do
    @note.save!
    @note.share_with(@student, 'read')
    
    assert_equal 1, @note.note_shares.count
    
    @note.unshare_with(@student)
    
    assert_equal 0, @note.note_shares.count
  end

  test "should check if note is shared with user" do
    @note.save!
    
    assert_not @note.shared_with?(@student)
    
    @note.share_with(@student, 'read')
    
    assert @note.shared_with?(@student)
  end

  test "should get user permission level" do
    @note.save!
    
    assert_nil @note.permission_for(@student)
    
    @note.share_with(@student, 'read')
    assert_equal 'read', @note.permission_for(@student)
    
    @note.share_with(@student, 'edit')
    assert_equal 'edit', @note.permission_for(@student)
  end

  # Tag Management Tests
  test "should add tags to note" do
    @note.save!
    
    @note.add_tag('algorithms')
    @note.add_tag('sorting')
    @note.add_tag('complexity')
    
    assert_equal 3, @note.note_tags.count
    tag_names = @note.note_tags.pluck(:name)
    assert_includes tag_names, 'algorithms'
    assert_includes tag_names, 'sorting'
    assert_includes tag_names, 'complexity'
  end

  test "should not add duplicate tags" do
    @note.save!
    
    @note.add_tag('algorithms')
    @note.add_tag('algorithms')  # Duplicate
    
    assert_equal 1, @note.note_tags.count
    assert_equal 'algorithms', @note.note_tags.first.name
  end

  test "should remove tags from note" do
    @note.save!
    @note.add_tag('algorithms')
    @note.add_tag('sorting')
    
    assert_equal 2, @note.note_tags.count
    
    @note.remove_tag('algorithms')
    
    assert_equal 1, @note.note_tags.count
    assert_equal 'sorting', @note.note_tags.first.name
  end

  test "should get all tag names" do
    @note.save!
    @note.add_tag('algorithms')
    @note.add_tag('sorting')
    @note.add_tag('complexity')
    
    tag_names = @note.tag_names
    assert_equal 3, tag_names.length
    assert_includes tag_names, 'algorithms'
    assert_includes tag_names, 'sorting'
    assert_includes tag_names, 'complexity'
  end

  test "should set tags from array" do
    @note.save!
    
    tags = ['algorithms', 'sorting', 'data-structures']
    @note.set_tags(tags)
    
    assert_equal 3, @note.note_tags.count
    assert_equal tags.sort, @note.tag_names.sort
  end

  test "should replace existing tags when setting new tags" do
    @note.save!
    @note.add_tag('old-tag')
    
    new_tags = ['new-tag1', 'new-tag2']
    @note.set_tags(new_tags)
    
    assert_equal 2, @note.note_tags.count
    assert_equal new_tags.sort, @note.tag_names.sort
    assert_not_includes @note.tag_names, 'old-tag'
  end

  # Scope Tests
  test "should filter by visibility" do
    @note.visibility = 'private'
    @note.save!
    
    department_note = Note.create!(
      title: 'Department Note',
      content: 'Visible to department',
      user: @teacher,
      department: @department,
      visibility: 'department',
      note_type: 'lecture'
    )
    
    public_note = Note.create!(
      title: 'Public Note',
      content: 'Visible to everyone',
      user: @teacher,
      department: @department,
      visibility: 'public',
      note_type: 'study_guide'
    )
    
    private_notes = Note.private_notes
    department_notes = Note.department_notes
    public_notes = Note.public_notes
    
    assert_includes private_notes, @note
    assert_not_includes private_notes, department_note
    assert_not_includes private_notes, public_note
    
    assert_includes department_notes, department_note
    assert_not_includes department_notes, @note
    assert_not_includes department_notes, public_note
    
    assert_includes public_notes, public_note
    assert_not_includes public_notes, @note
    assert_not_includes public_notes, department_note
  end

  test "should filter by note type" do
    @note.save!
    
    lecture_note = Note.create!(
      title: 'Lecture Note',
      content: 'Lecture content',
      user: @teacher,
      department: @department,
      visibility: 'private',
      note_type: 'lecture'
    )
    
    assignment_note = Note.create!(
      title: 'Assignment Note',
      content: 'Assignment details',
      user: @teacher,
      department: @department,
      visibility: 'private',
      note_type: 'assignment'
    )
    
    study_guide_notes = Note.of_type('study_guide')
    lecture_notes = Note.of_type('lecture')
    assignment_notes = Note.of_type('assignment')
    
    assert_includes study_guide_notes, @note
    assert_not_includes study_guide_notes, lecture_note
    assert_not_includes study_guide_notes, assignment_note
    
    assert_includes lecture_notes, lecture_note
    assert_includes assignment_notes, assignment_note
  end

  test "should filter by department" do
    @note.save!
    
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_note = Note.create!(
      title: 'Physics Note',
      content: 'Physics content',
      user: @teacher,
      department: physics_dept,
      visibility: 'department',
      note_type: 'lecture'
    )
    
    cs_notes = Note.for_department(@department)
    physics_notes = Note.for_department(physics_dept)
    
    assert_includes cs_notes, @note
    assert_not_includes cs_notes, physics_note
    assert_includes physics_notes, physics_note
    assert_not_includes physics_notes, @note
  end

  test "should filter by user" do
    @note.save!
    
    student_note = Note.create!(
      title: 'Student Note',
      content: 'Student content',
      user: @student,
      department: @department,
      visibility: 'private',
      note_type: 'personal'
    )
    
    teacher_notes = Note.by_user(@teacher)
    student_notes = Note.by_user(@student)
    
    assert_includes teacher_notes, @note
    assert_not_includes teacher_notes, student_note
    assert_includes student_notes, student_note
    assert_not_includes student_notes, @note
  end

  test "should filter accessible notes for user" do
    # Private note (not accessible to student)
    private_note = Note.create!(
      title: 'Private Note',
      content: 'Private content',
      user: @teacher,
      department: @department,
      visibility: 'private',
      note_type: 'personal'
    )
    
    # Department note (accessible to department members)
    department_note = Note.create!(
      title: 'Department Note',
      content: 'Department content',
      user: @teacher,
      department: @department,
      visibility: 'department',
      note_type: 'lecture'
    )
    
    # Public note (accessible to everyone)
    public_note = Note.create!(
      title: 'Public Note',
      content: 'Public content',
      user: @teacher,
      department: @department,
      visibility: 'public',
      note_type: 'study_guide'
    )
    
    # Shared note (accessible through sharing)
    shared_note = Note.create!(
      title: 'Shared Note',
      content: 'Shared content',
      user: @teacher,
      department: @department,
      visibility: 'private',
      note_type: 'assignment'
    )
    shared_note.share_with(@student, 'read')
    
    accessible_notes = Note.accessible_to(@student)
    
    assert_not_includes accessible_notes, private_note
    assert_includes accessible_notes, department_note
    assert_includes accessible_notes, public_note
    assert_includes accessible_notes, shared_note
  end

  test "should search notes by content" do
    @note.content = 'This note contains algorithms and data structures concepts.'
    @note.save!
    
    other_note = Note.create!(
      title: 'Database Note',
      content: 'This note discusses SQL queries and database design.',
      user: @teacher,
      department: @department,
      visibility: 'private',
      note_type: 'lecture'
    )
    
    algorithm_results = Note.search_content('algorithms')
    database_results = Note.search_content('database')
    
    assert_includes algorithm_results, @note
    assert_not_includes algorithm_results, other_note
    assert_includes database_results, other_note
    assert_not_includes database_results, @note
  end

  test "should order notes by updated_at" do
    @note.save!
    
    travel_to 1.hour.ago do
      @older_note = Note.create!(
        title: 'Older Note',
        content: 'This is older',
        user: @teacher,
        department: @department,
        visibility: 'private',
        note_type: 'lecture'
      )
    end
    
    travel_to 2.hours.from_now do
      @newer_note = Note.create!(
        title: 'Newer Note',
        content: 'This is newer',
        user: @teacher,
        department: @department,
        visibility: 'private',
        note_type: 'study_guide'
      )
    end
    
    recent_notes = Note.recent
    assert_equal [@newer_note, @note, @older_note], recent_notes.limit(3).to_a
  end

  # Content Processing Tests
  test "should calculate word count" do
    @note.content = 'This is a test note with exactly ten words in it.'
    @note.save!
    
    assert_equal 11, @note.word_count
  end

  test "should handle empty content for word count" do
    @note.content = ''
    
    # Note won't save due to validation, but method should handle empty content
    assert_equal 0, @note.word_count
  end

  test "should estimate reading time" do
    # Average reading speed is about 200 words per minute
    @note.content = 'word ' * 400  # 400 words
    @note.save!
    
    # Should be approximately 2 minutes
    reading_time = @note.estimated_reading_time
    assert reading_time >= 1
    assert reading_time <= 3
  end

  test "should extract summary from content" do
    long_content = 'This is the first sentence. ' * 10 + 'This is additional content. ' * 20
    @note.content = long_content
    @note.save!
    
    summary = @note.summary(100)  # First 100 characters
    assert summary.length <= 103  # 100 + '...'
    assert summary.starts_with?('This is the first sentence.')
    assert summary.ends_with?('...')
  end

  # Activity Tracking Tests
  test "should track last access time" do
    @note.save!
    
    freeze_time = Time.current
    travel_to freeze_time do
      @note.mark_accessed!
      assert_equal freeze_time.to_i, @note.last_accessed_at.to_i
    end
  end

  test "should track view count" do
    @note.save!
    
    initial_count = @note.view_count || 0
    @note.increment_view_count!
    
    assert_equal initial_count + 1, @note.view_count
  end

  # Version Control Tests (if implemented)
  test "should track content changes" do
    @note.save!
    original_content = @note.content
    
    @note.update!(content: 'Updated content with new information.')
    
    # If versioning is implemented, original content should be tracked
    # This test assumes basic updated_at tracking
    assert_not_equal original_content, @note.content
    assert @note.updated_at > @note.created_at
  end

  # Edge Cases
  test "should handle very long content" do
    very_long_content = 'a' * 10000
    @note.content = very_long_content
    
    assert @note.valid?
    
    @note.save!
    assert_equal very_long_content, @note.reload.content
  end

  test "should handle special characters in tags" do
    @note.save!
    
    special_tags = ['C++', 'C#', 'Node.js', 'ASP.NET']
    special_tags.each do |tag|
      @note.add_tag(tag)
    end
    
    assert_equal special_tags.length, @note.note_tags.count
    assert_equal special_tags.sort, @note.tag_names.sort
  end

  test "should handle mass sharing operations" do
    @note.save!
    
    users = []
    5.times do |i|
      users << User.create!(
        email: "user#{i}@test.com",
        password: 'password123',
        first_name: 'User',
        last_name: i.to_s,
        role: 'student'
      )
    end
    
    users.each do |user|
      @note.share_with(user, 'read')
    end
    
    assert_equal 5, @note.note_shares.count
    assert_equal users.sort_by(&:id), @note.shared_users.sort_by(&:id)
  end

  # Performance Tests
  test "should efficiently load shared users and tags" do
    @note.save!
    
    # Add multiple shares and tags
    10.times do |i|
      user = User.create!(
        email: "shared#{i}@test.com",
        password: 'password123',
        first_name: 'Shared',
        last_name: i.to_s,
        role: 'student'
      )
      @note.share_with(user, 'read')
      @note.add_tag("tag#{i}")
    end
    
    # Query with includes should be efficient
    note_with_associations = Note.includes(:shared_users, :note_tags).find(@note.id)
    
    assert_no_queries do
      note_with_associations.shared_users.each(&:full_name)
      note_with_associations.note_tags.each(&:name)
    end
  end
end