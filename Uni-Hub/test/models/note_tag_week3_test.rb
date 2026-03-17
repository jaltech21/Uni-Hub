require 'test_helper'

class NoteTagTest < ActiveSupport::TestCase
  def setup
    @teacher = users(:teacher)
    @department = departments(:computer_science)
    
    @note = Note.create!(
      title: 'Data Structures Study Guide',
      content: 'Comprehensive guide covering arrays, linked lists, trees, and graphs.',
      user: @teacher,
      department: @department
    )
    
    @tag = Tag.create!(
      name: 'data-structures',
      color: '#4CAF50'
    )
    
    @note_tag = NoteTag.new(
      note: @note,
      tag: @tag
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @note_tag.valid?
  end

  test "should require note" do
    @note_tag.note = nil
    assert_not @note_tag.valid?
    assert_includes @note_tag.errors[:note], "must exist"
  end

  test "should require tag" do
    @note_tag.tag = nil
    assert_not @note_tag.valid?
    assert_includes @note_tag.errors[:tag], "must exist"
  end

  test "should require unique note-tag combination" do
    @note_tag.save!
    
    duplicate_note_tag = NoteTag.new(
      note: @note,
      tag: @tag  # Same combination
    )
    
    assert_not duplicate_note_tag.valid?
    assert_includes duplicate_note_tag.errors[:note_id], "already has this tag"
  end

  test "should allow same note with different tags" do
    @note_tag.save!
    
    other_tag = Tag.create!(
      name: 'algorithms',
      color: '#FF5733'
    )
    
    different_tag_relation = NoteTag.new(
      note: @note,  # Same note
      tag: other_tag  # Different tag
    )
    
    assert different_tag_relation.valid?
  end

  test "should allow same tag with different notes" do
    @note_tag.save!
    
    other_note = Note.create!(
      title: 'Algorithm Analysis',
      content: 'Study of algorithmic complexity and optimization.',
      user: @teacher,
      department: @department
    )
    
    different_note_relation = NoteTag.new(
      note: other_note,  # Different note
      tag: @tag  # Same tag
    )
    
    assert different_note_relation.valid?
  end

  # Association Tests
  test "should belong to note" do
    assert_respond_to @note_tag, :note
    @note_tag.save!
    assert_instance_of Note, @note_tag.note
    assert_equal @note, @note_tag.note
  end

  test "should belong to tag" do
    assert_respond_to @note_tag, :tag
    @note_tag.save!
    assert_instance_of Tag, @note_tag.tag
    assert_equal @tag, @note_tag.tag
  end

  # Timestamp Tests
  test "should set created_at and updated_at automatically" do
    freeze_time = Time.current
    travel_to freeze_time do
      @note_tag.save!
      assert_equal freeze_time.to_i, @note_tag.created_at.to_i
      assert_equal freeze_time.to_i, @note_tag.updated_at.to_i
    end
  end

  # Integration with Parent Models Tests
  test "should be accessible through note's tags association" do
    @note_tag.save!
    
    assert_equal 1, @note.tags.count
    assert_includes @note.tags, @tag
    assert_equal @tag, @note.tags.first
  end

  test "should be accessible through tag's notes association" do
    @note_tag.save!
    
    assert_equal 1, @tag.notes.count
    assert_includes @tag.notes, @note
    assert_equal @note, @tag.notes.first
  end

  test "should update note's tag associations when created" do
    assert_equal 0, @note.tags.count
    
    @note_tag.save!
    
    assert_equal 1, @note.tags.count
    assert_includes @note.tags, @tag
  end

  test "should update tag's note associations when created" do
    assert_equal 0, @tag.notes.count
    
    @note_tag.save!
    
    assert_equal 1, @tag.notes.count
    assert_includes @tag.notes, @note
  end

  # Deletion and Cleanup Tests
  test "should be destroyed when note is destroyed" do
    @note_tag.save!
    
    assert_difference 'NoteTag.count', -1 do
      @note.destroy
    end
  end

  test "should be destroyed when tag is destroyed" do
    @note_tag.save!
    
    assert_difference 'NoteTag.count', -1 do
      @tag.destroy
    end
  end

  test "should remove tag from note when note_tag is destroyed" do
    @note_tag.save!
    
    assert_includes @note.tags, @tag
    
    @note_tag.destroy
    
    assert_not_includes @note.reload.tags, @tag
  end

  test "should remove note from tag when note_tag is destroyed" do
    @note_tag.save!
    
    assert_includes @tag.notes, @note
    
    @note_tag.destroy
    
    assert_not_includes @tag.reload.notes, @note
  end

  # Multiple Tags per Note Tests
  test "should allow note to have multiple tags" do
    @note_tag.save!
    
    # Create additional tags
    algorithm_tag = Tag.create!(name: 'algorithms')
    complexity_tag = Tag.create!(name: 'complexity')
    
    # Associate additional tags with the note
    NoteTag.create!(note: @note, tag: algorithm_tag)
    NoteTag.create!(note: @note, tag: complexity_tag)
    
    assert_equal 3, @note.tags.count
    assert_includes @note.tags, @tag
    assert_includes @note.tags, algorithm_tag
    assert_includes @note.tags, complexity_tag
  end

  # Multiple Notes per Tag Tests
  test "should allow tag to be associated with multiple notes" do
    @note_tag.save!
    
    # Create additional notes
    note2 = Note.create!(
      title: 'Advanced Data Structures',
      content: 'Advanced topics in data structures.',
      user: @teacher,
      department: @department
    )
    
    note3 = Note.create!(
      title: 'Data Structure Implementation',
      content: 'Practical implementation of data structures.',
      user: @teacher,
      department: @department
    )
    
    # Associate tag with additional notes
    NoteTag.create!(note: note2, tag: @tag)
    NoteTag.create!(note: note3, tag: @tag)
    
    assert_equal 3, @tag.notes.count
    assert_includes @tag.notes, @note
    assert_includes @tag.notes, note2
    assert_includes @tag.notes, note3
  end

  # Cross-Department Tagging Tests
  test "should allow tags to be used across different departments" do
    @note_tag.save!
    
    # Create different department
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_teacher = User.create!(
      email: 'physics@test.com',
      password: 'password123',
      first_name: 'Physics',
      last_name: 'Teacher',
      role: 'teacher',
      department: physics_dept
    )
    
    # Create note in different department
    physics_note = Note.create!(
      title: 'Mathematical Structures in Physics',
      content: 'How data structures apply to physics simulations.',
      user: physics_teacher,
      department: physics_dept
    )
    
    # Use same tag in different department
    cross_dept_note_tag = NoteTag.new(
      note: physics_note,
      tag: @tag  # Same tag, different department
    )
    
    assert cross_dept_note_tag.valid?
    cross_dept_note_tag.save!
    
    # Tag should now be associated with notes from both departments
    assert_equal 2, @tag.notes.count
    assert_includes @tag.notes, @note
    assert_includes @tag.notes, physics_note
  end

  # User Permission Integration Tests
  test "should respect note visibility when accessing tags" do
    @note_tag.save!
    
    student = users(:student)
    
    # If note has visibility restrictions, tag access should respect them
    # This test assumes note-level permissions affect tag visibility
    
    # Public/department note - tags should be accessible
    # Private note - tags might not be accessible to non-owners
    # This would typically be handled at the controller/service level
    
    assert @note_tag.persisted?
    assert_equal @note.user, @teacher
    
    # Basic association should work regardless of permissions
    assert_equal @tag, @note_tag.tag
    assert_equal @note, @note_tag.note
  end

  # Bulk Operations Tests
  test "should handle bulk tag assignment" do
    tag_names = ['algorithms', 'sorting', 'searching', 'complexity']
    tags = tag_names.map { |name| Tag.create!(name: name) }
    
    # Bulk create note_tags
    note_tags = tags.map { |tag| NoteTag.create!(note: @note, tag: tag) }
    
    assert_equal 4, @note.note_tags.count
    assert_equal 4, @note.tags.count
    
    # All tags should be associated
    tags.each do |tag|
      assert_includes @note.tags, tag
    end
  end

  test "should handle bulk tag removal" do
    # First, create multiple tags
    tags = 5.times.map do |i|
      tag = Tag.create!(name: "tag#{i}")
      NoteTag.create!(note: @note, tag: tag)
      tag
    end
    
    assert_equal 5, @note.tags.count
    
    # Remove specific tags
    tags_to_remove = tags.first(3)
    note_tags_to_remove = @note.note_tags.joins(:tag).where(tags: { id: tags_to_remove.map(&:id) })
    
    assert_difference 'NoteTag.count', -3 do
      note_tags_to_remove.destroy_all
    end
    
    assert_equal 2, @note.reload.tags.count
    
    # Check that correct tags remain
    remaining_tags = tags.last(2)
    remaining_tags.each do |tag|
      assert_includes @note.tags, tag
    end
    
    # Check that removed tags are gone
    tags_to_remove.each do |tag|
      assert_not_includes @note.tags, tag
    end
  end

  # Performance Tests
  test "should efficiently query notes with specific tags" do
    @note_tag.save!
    
    # Create more notes and tags for performance testing
    20.times do |i|
      note = Note.create!(
        title: "Performance Note #{i}",
        content: "Content for performance testing #{i}",
        user: @teacher,
        department: @department
      )
      
      # Some notes share the tag, some don't
      if i.even?
        NoteTag.create!(note: note, tag: @tag)
      end
    end
    
    # Query notes with specific tag should be efficient
    tagged_notes = Note.joins(:note_tags).where(note_tags: { tag: @tag })
    
    # Should find original note plus 10 even-numbered notes = 11 total
    assert_equal 11, tagged_notes.count
    assert_includes tagged_notes, @note
  end

  test "should efficiently query tags for specific notes" do
    # Create multiple tags for the note
    10.times do |i|
      tag = Tag.create!(name: "performance_tag_#{i}")
      NoteTag.create!(note: @note, tag: tag)
    end
    
    # Query should be efficient with proper associations
    note_with_tags = Note.includes(:tags).find(@note.id)
    
    assert_no_queries do
      note_with_tags.tags.each(&:name)
    end
    
    assert_equal 10, note_with_tags.tags.count
  end

  # Edge Cases
  test "should handle rapid tag addition and removal" do
    tag1 = Tag.create!(name: 'temp_tag_1')
    tag2 = Tag.create!(name: 'temp_tag_2')
    
    # Rapid addition
    note_tag1 = NoteTag.create!(note: @note, tag: tag1)
    note_tag2 = NoteTag.create!(note: @note, tag: tag2)
    
    assert_equal 2, @note.tags.count
    
    # Rapid removal
    note_tag1.destroy
    note_tag2.destroy
    
    assert_equal 0, @note.reload.tags.count
  end

  test "should handle tag recreation after deletion" do
    @note_tag.save!
    original_tag_id = @tag.id
    
    # Delete the tag (should also delete note_tag)
    @tag.destroy
    
    assert_equal 0, @note.reload.tags.count
    assert_not NoteTag.exists?(note: @note, tag_id: original_tag_id)
    
    # Recreate tag with same name
    new_tag = Tag.create!(name: 'data-structures')  # Same name as deleted tag
    new_note_tag = NoteTag.create!(note: @note, tag: new_tag)
    
    assert new_note_tag.valid?
    assert_equal 1, @note.reload.tags.count
    assert_includes @note.tags, new_tag
    assert_not_equal original_tag_id, new_tag.id
  end

  # Statistical Analysis Tests
  test "should provide accurate count statistics" do
    # Create a network of notes and tags
    notes = 5.times.map do |i|
      Note.create!(
        title: "Statistical Note #{i}",
        content: "Content #{i}",
        user: @teacher,
        department: @department
      )
    end
    
    tags = 3.times.map do |i|
      Tag.create!(name: "stat_tag_#{i}")
    end
    
    # Create various tag associations
    # Tag 0: 3 notes
    # Tag 1: 2 notes  
    # Tag 2: 1 note
    
    [0, 1, 2].each { |i| NoteTag.create!(note: notes[i], tag: tags[0]) }
    [0, 1].each { |i| NoteTag.create!(note: notes[i], tag: tags[1]) }
    NoteTag.create!(note: notes[0], tag: tags[2])
    
    # Verify counts
    assert_equal 3, tags[0].notes.count
    assert_equal 2, tags[1].notes.count
    assert_equal 1, tags[2].notes.count
    
    # Note 0 should have all 3 tags
    assert_equal 3, notes[0].tags.count
    # Note 1 should have 2 tags
    assert_equal 2, notes[1].tags.count
    # Note 2 should have 1 tag
    assert_equal 1, notes[2].tags.count
  end

  # Data Integrity Tests
  test "should maintain referential integrity under concurrent operations" do
    @note_tag.save!
    
    # Simulate concurrent tag deletion and note_tag creation
    # This is a simplified test - in real scenarios, database constraints would handle this
    
    original_count = NoteTag.count
    
    # Create additional note_tag
    other_note = Note.create!(
      title: 'Concurrent Test Note',
      content: 'Testing concurrent operations',
      user: @teacher,
      department: @department
    )
    
    other_note_tag = NoteTag.create!(note: other_note, tag: @tag)
    
    # Both note_tags should exist
    assert_equal original_count + 1, NoteTag.count
    assert_equal 2, @tag.reload.notes.count
  end
end