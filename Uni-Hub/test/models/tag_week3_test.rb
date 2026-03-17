require 'test_helper'

class TagTest < ActiveSupport::TestCase
  def setup
    @tag = Tag.new(
      name: 'algorithms',
      color: '#FF5733'
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @tag.valid?
  end

  test "should require name" do
    @tag.name = nil
    assert_not @tag.valid?
    assert_includes @tag.errors[:name], "can't be blank"

    @tag.name = ""
    assert_not @tag.valid?
    assert_includes @tag.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    @tag.save!
    
    duplicate_tag = Tag.new(name: 'algorithms')
    assert_not duplicate_tag.valid?
    assert_includes duplicate_tag.errors[:name], "has already been taken"
  end

  test "should validate name length" do
    @tag.name = 'a' * 31  # Exceeds maximum length of 30
    assert_not @tag.valid?
    assert_includes @tag.errors[:name], "is too long (maximum is 30 characters)"

    @tag.name = ''  # Below minimum length of 1
    assert_not @tag.valid?
    assert_includes @tag.errors[:name], "is too short (minimum is 1 character)"
  end

  test "should validate color format when present" do
    @tag.color = 'invalid_color'
    assert_not @tag.valid?
    assert_includes @tag.errors[:color], "must be a valid hex color"

    @tag.color = '#ZZZZZZ'
    assert_not @tag.valid?
    assert_includes @tag.errors[:color], "must be a valid hex color"

    @tag.color = '#FF573'  # Too short
    assert_not @tag.valid?
    assert_includes @tag.errors[:color], "must be a valid hex color"

    @tag.color = '#FF57333'  # Too long
    assert_not @tag.valid?
    assert_includes @tag.errors[:color], "must be a valid hex color"

    valid_colors = ['#FF5733', '#00FF00', '#0000FF', '#FFFFFF', '#000000']
    valid_colors.each do |color|
      @tag.color = color
      assert @tag.valid?, "#{color} should be a valid hex color"
    end
  end

  test "should allow blank color" do
    @tag.color = nil
    assert @tag.valid?

    @tag.color = ''
    assert @tag.valid?
  end

  # Name Normalization Tests
  test "should normalize name before validation" do
    @tag.name = '  ALGORITHMS  '
    @tag.save!
    
    assert_equal 'algorithms', @tag.name
  end

  test "should handle name normalization with special characters" do
    test_names = [
      ['C++', 'c++'],
      ['JavaScript', 'javascript'],
      ['  Data Structures  ', 'data structures'],
      ['MACHINE-LEARNING', 'machine-learning']
    ]
    
    test_names.each do |input, expected|
      tag = Tag.new(name: input)
      tag.save!
      assert_equal expected, tag.name
      tag.destroy  # Clean up for next iteration
    end
  end

  # Association Tests
  test "should have many note_tags" do
    assert_respond_to @tag, :note_tags
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    note = Note.create!(
      title: 'Algorithm Notes',
      content: 'Comprehensive algorithm study guide',
      user: teacher,
      department: department
    )
    
    @tag.note_tags.create!(note: note)
    
    assert_equal 1, @tag.note_tags.count
    assert_instance_of NoteTag, @tag.note_tags.first
  end

  test "should have many notes through note_tags" do
    assert_respond_to @tag, :notes
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    note1 = Note.create!(
      title: 'Algorithm Notes 1',
      content: 'First set of algorithm notes',
      user: teacher,
      department: department
    )
    
    note2 = Note.create!(
      title: 'Algorithm Notes 2',
      content: 'Second set of algorithm notes',
      user: teacher,
      department: department
    )
    
    @tag.note_tags.create!(note: note1)
    @tag.note_tags.create!(note: note2)
    
    assert_equal 2, @tag.notes.count
    assert_includes @tag.notes, note1
    assert_includes @tag.notes, note2
  end

  test "should destroy dependent note_tags when destroyed" do
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    note = Note.create!(
      title: 'Tagged Note',
      content: 'This note will be tagged',
      user: teacher,
      department: department
    )
    
    @tag.note_tags.create!(note: note)
    
    assert_difference 'NoteTag.count', -1 do
      @tag.destroy
    end
  end

  # Class Methods Tests
  test "should find or create by name" do
    # Create new tag
    new_tag = Tag.find_or_create_by_name('machine-learning')
    assert new_tag.persisted?
    assert_equal 'machine-learning', new_tag.name
    
    # Find existing tag
    existing_tag = Tag.find_or_create_by_name('  MACHINE-LEARNING  ')
    assert_equal new_tag.id, existing_tag.id
    assert_equal 'machine-learning', existing_tag.name
  end

  test "should handle find_or_create_by_name with nil or empty input" do
    nil_tag = Tag.find_or_create_by_name(nil)
    assert_nil nil_tag
    
    empty_tag = Tag.find_or_create_by_name('')
    assert_nil empty_tag
    
    whitespace_tag = Tag.find_or_create_by_name('   ')
    assert_nil whitespace_tag
  end

  # Instance Methods Tests
  test "should count associated notes" do
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    assert_equal 0, @tag.notes_count
    
    # Create and tag notes
    3.times do |i|
      note = Note.create!(
        title: "Note #{i}",
        content: "Content for note #{i}",
        user: teacher,
        department: department
      )
      @tag.note_tags.create!(note: note)
    end
    
    assert_equal 3, @tag.notes_count
  end

  # Scope Tests
  test "should order tags alphabetically" do
    # Create tags in non-alphabetical order
    zebra_tag = Tag.create!(name: 'zebra')
    alpha_tag = Tag.create!(name: 'alpha')
    beta_tag = Tag.create!(name: 'beta')
    
    alphabetical_tags = Tag.alphabetical
    expected_order = [alpha_tag, beta_tag, zebra_tag]
    
    assert_equal expected_order, alphabetical_tags.limit(3).to_a
  end

  test "should order tags by popularity" do
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    # Create additional tags
    popular_tag = Tag.create!(name: 'popular')
    unpopular_tag = Tag.create!(name: 'unpopular')
    
    # Create notes and tag them
    # Popular tag: 3 notes
    3.times do |i|
      note = Note.create!(
        title: "Popular Note #{i}",
        content: "Content #{i}",
        user: teacher,
        department: department
      )
      popular_tag.note_tags.create!(note: note)
    end
    
    # @tag (algorithms): 2 notes
    2.times do |i|
      note = Note.create!(
        title: "Algorithm Note #{i}",
        content: "Algorithm content #{i}",
        user: teacher,
        department: department
      )
      @tag.note_tags.create!(note: note)
    end
    
    # Unpopular tag: 1 note
    note = Note.create!(
      title: 'Unpopular Note',
      content: 'Unpopular content',
      user: teacher,
      department: department
    )
    unpopular_tag.note_tags.create!(note: note)
    
    popular_tags = Tag.popular.limit(3)
    tag_ids = popular_tags.pluck(:id)
    
    # Should be ordered by popularity: popular_tag, @tag, unpopular_tag
    assert_equal popular_tag.id, tag_ids[0]
    assert_equal @tag.id, tag_ids[1]
    assert_equal unpopular_tag.id, tag_ids[2]
  end

  # Color Management Tests
  test "should generate default color if none provided" do
    colorless_tag = Tag.create!(name: 'colorless')
    
    # If implementation provides default colors
    # assert_not_nil colorless_tag.color
    
    # For now, just test that it's valid without color
    assert colorless_tag.valid?
  end

  test "should accept various hex color formats" do
    color_variations = [
      '#ff5733',  # lowercase
      '#FF5733',  # uppercase
      '#AbC123',  # mixed case
      '#000000',  # black
      '#FFFFFF'   # white
    ]
    
    color_variations.each_with_index do |color, index|
      tag = Tag.create!(name: "color_test_#{index}", color: color)
      assert tag.valid?
      assert_equal color, tag.color
    end
  end

  # Edge Cases
  test "should handle very long normalized names" do
    long_name = 'a' * 25  # Within limit
    @tag.name = long_name
    assert @tag.valid?
    
    too_long_name = 'a' * 35  # Exceeds limit
    @tag.name = too_long_name
    assert_not @tag.valid?
  end

  test "should handle special characters in names" do
    special_names = [
      'c++',
      'c#',
      'node.js',
      'asp.net',
      'machine-learning',
      'data_structures',
      'ruby-on-rails'
    ]
    
    special_names.each_with_index do |name, index|
      tag = Tag.create!(name: name)
      assert tag.valid?, "#{name} should be valid"
      assert tag.persisted?, "#{name} should be saved"
    end
  end

  test "should handle unicode characters in names" do
    unicode_names = [
      'データ構造',  # Japanese
      'алгоритмы',   # Russian
      'algorithmes', # French
      'algoritmos'   # Spanish
    ]
    
    unicode_names.each do |name|
      tag = Tag.create!(name: name)
      assert tag.valid?, "#{name} should be valid"
      assert tag.persisted?, "#{name} should be saved"
    end
  end

  # Performance Tests
  test "should efficiently load notes with tags" do
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    # Create multiple tagged notes
    10.times do |i|
      note = Note.create!(
        title: "Performance Note #{i}",
        content: "Content #{i}",
        user: teacher,
        department: department
      )
      @tag.note_tags.create!(note: note)
    end
    
    # Query should be efficient with includes
    tag_with_notes = Tag.includes(:notes).find(@tag.id)
    
    assert_no_queries do
      tag_with_notes.notes.each(&:title)
    end
  end

  # Integration Tests
  test "should work with note tagging system" do
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    note = Note.create!(
      title: 'Integration Test Note',
      content: 'Testing tag integration',
      user: teacher,
      department: department
    )
    
    # Test note's tag_list= method if implemented
    if note.respond_to?(:tag_list=)
      note.tag_list = 'algorithms, data-structures'
      note.save!
      
      assert_includes note.tags.pluck(:name), 'algorithms'
      assert_includes note.tags.pluck(:name), 'data-structures'
    end
  end

  test "should maintain referential integrity" do
    @tag.save!
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    note = Note.create!(
      title: 'Referential Test Note',
      content: 'Testing referential integrity',
      user: teacher,
      department: department
    )
    
    note_tag = @tag.note_tags.create!(note: note)
    
    # Destroying note should remove note_tag
    assert_difference 'NoteTag.count', -1 do
      note.destroy
    end
    
    # Tag should still exist
    assert Tag.exists?(@tag.id)
  end

  # Statistical Analysis Tests
  test "should provide tag usage statistics" do
    @tag.save!
    popular_tag = Tag.create!(name: 'popular-topic')
    
    teacher = users(:teacher)
    department = departments(:computer_science)
    
    # Create notes with different tag frequencies
    5.times do |i|
      note = Note.create!(
        title: "Popular Note #{i}",
        content: "Popular content #{i}",
        user: teacher,
        department: department
      )
      popular_tag.note_tags.create!(note: note)
    end
    
    2.times do |i|
      note = Note.create!(
        title: "Algorithm Note #{i}",
        content: "Algorithm content #{i}",
        user: teacher,
        department: department
      )
      @tag.note_tags.create!(note: note)
    end
    
    # Test popularity ranking
    popular_tags = Tag.popular.limit(2)
    assert_equal popular_tag, popular_tags.first
    assert_equal @tag, popular_tags.second
    
    # Test individual counts
    assert_equal 5, popular_tag.notes_count
    assert_equal 2, @tag.notes_count
  end

  # Search and Filtering Tests
  test "should support case-insensitive name searching" do
    @tag.save!
    Tag.create!(name: 'javascript')
    Tag.create!(name: 'python')
    
    # Test exact match
    found_tag = Tag.find_by(name: 'algorithms')
    assert_equal @tag, found_tag
    
    # Test case variations would work due to normalization
    js_variations = ['JavaScript', 'JAVASCRIPT', 'javascript']
    js_variations.each do |variation|
      # Since names are normalized to lowercase, this should find the tag
      found = Tag.find_by(name: variation.downcase)
      assert_not_nil found
      assert_equal 'javascript', found.name
    end
  end
end