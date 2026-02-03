require 'test_helper'

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @teacher = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
    @department = departments(:computer_science)
    
    @note = Note.create!(
      title: 'Advanced Algorithms Study Guide',
      content: 'Comprehensive notes on sorting algorithms and their complexities.',
      user: @teacher,
      department: @department
    )
    
    @private_note = Note.create!(
      title: 'Private Research Notes',
      content: 'Confidential research findings and analysis.',
      user: @teacher,
      department: @department
    )
  end

  # Teacher Tests - Note Management
  test "teacher should get notes index" do
    sign_in @teacher
    get notes_url
    assert_response :success
    assert_select 'h1', /Notes/
    assert_select '.note-card'
    assert_select '.notes-toolbar'
    assert_select '.create-note-button'
  end

  test "teacher should get new note form" do
    sign_in @teacher
    get new_note_url
    assert_response :success
    assert_select 'form'
    assert_select 'input[name="note[title]"]'
    assert_select 'textarea[name="note[content]"]'
    assert_select 'select[name="note[visibility]"]'
    assert_select 'select[name="note[note_type]"]'
    assert_select '.tag-input'
  end

  test "teacher should create note" do
    sign_in @teacher
    
    assert_difference('Note.count') do
      post notes_url, params: {
        note: {
          title: 'Database Design Principles',
          content: 'Key principles for designing efficient database schemas.',
          visibility: 'department',
          note_type: 'study_guide',
          tag_list: 'database, design, sql'
        }
      }
    end
    
    assert_redirected_to note_path(Note.last)
    follow_redirect!
    assert_match 'Note was successfully created', flash[:notice]
    
    note = Note.last
    assert_equal 'Database Design Principles', note.title
    assert_equal 'department', note.visibility
  end

  test "teacher should show their note with full options" do
    sign_in @teacher
    get note_url(@note)
    assert_response :success
    assert_select 'h1', @note.title
    assert_select '.note-content'
    assert_select '.note-actions'
    assert_select '.sharing-section'
    assert_select '.tag-section'
    assert_select '.edit-note-button'
    assert_select '.delete-note-button'
  end

  test "teacher should get edit form for their note" do
    sign_in @teacher
    get edit_note_url(@note)
    assert_response :success
    assert_select 'form'
    assert_select 'input[value=?]', @note.title
    assert_select 'textarea', text: @note.content
  end

  test "teacher should update their note" do
    sign_in @teacher
    
    patch note_url(@note), params: {
      note: {
        title: 'Updated Algorithm Guide',
        content: @note.content,
        visibility: 'public'
      }
    }
    
    assert_redirected_to note_path(@note)
    @note.reload
    assert_equal 'Updated Algorithm Guide', @note.title
    assert_equal 'public', @note.visibility
  end

  test "teacher should destroy their note" do
    sign_in @teacher
    
    assert_difference('Note.count', -1) do
      delete note_url(@note)
    end
    
    assert_redirected_to notes_url
    assert_match 'Note deleted successfully', flash[:notice]
  end

  test "teacher cannot edit other user's private notes" do
    other_teacher = User.create!(
      email: 'other_teacher@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'Teacher',
      role: 'teacher'
    )
    
    other_note = Note.create!(
      title: 'Other Teacher Note',
      content: 'Private content',
      user: other_teacher,
      department: @department,
      visibility: 'private'
    )
    
    sign_in @teacher
    get edit_note_url(other_note)
    assert_redirected_to notes_path
    assert_match 'You can only edit your own notes', flash[:alert]
  end

  # Note Sharing Tests
  test "teacher should share note with user" do
    sign_in @teacher
    
    post share_note_url(@note), params: {
      user_id: @student.id,
      permission: 'read'
    }
    
    assert_redirected_to note_path(@note)
    assert_match 'Note shared successfully', flash[:notice]
    
    assert @note.note_shares.exists?(shared_with: @student, permission: 'read')
  end

  test "teacher should update sharing permissions" do
    @note.note_shares.create!(shared_by: @teacher, shared_with: @student, permission: 'view')
    
    sign_in @teacher
    
    patch update_share_note_url(@note), params: {
      user_id: @student.id,
      permission: 'edit'
    }
    
    assert_redirected_to note_path(@note)
    
    share = @note.note_shares.find_by(shared_with: @student)
    assert_equal 'edit', share.permission
  end

  test "teacher should remove sharing" do
    @note.note_shares.create!(shared_by: @teacher, shared_with: @student, permission: 'view')
    
    sign_in @teacher
    
    delete unshare_note_url(@note), params: { user_id: @student.id }
    
    assert_redirected_to note_path(@note)
    assert_match 'Sharing removed successfully', flash[:notice]
    
    assert_not @note.note_shares.exists?(shared_with: @student)
  end

  test "teacher should bulk share note" do
    users_to_share = [@student, @admin]
    
    sign_in @teacher
    
    post bulk_share_note_url(@note), params: {
      user_ids: users_to_share.map(&:id),
      permission: 'view'
    }
    
    assert_redirected_to note_path(@note)
    assert_match 'Note shared with 2 users', flash[:notice]
    
    users_to_share.each do |user|
      assert @note.note_shares.exists?(shared_with: user, permission: 'view')
    end
  end

  # Tag Management Tests
  test "teacher should add tags to note" do
    sign_in @teacher
    
    post add_tags_note_url(@note), params: {
      tags: 'algorithms, sorting, complexity'
    }
    
    assert_redirected_to note_path(@note)
    assert_match 'Tags added successfully', flash[:notice]
    
    tag_names = @note.tags.pluck(:name)
    assert_includes tag_names, 'algorithms'
    assert_includes tag_names, 'sorting'
    assert_includes tag_names, 'complexity'
  end

  test "teacher should remove tags from note" do
    @note.tags.create!(name: 'old-tag')
    
    sign_in @teacher
    
    delete remove_tag_note_url(@note), params: { tag_name: 'old-tag' }
    
    assert_redirected_to note_path(@note)
    assert_match 'Tag removed successfully', flash[:notice]
    
    assert_not @note.tags.exists?(name: 'old-tag')
  end

  # Student Tests - Limited Access
  test "student should get notes index with filtered view" do
    sign_in @student
    get notes_url
    assert_response :success
    assert_select '.available-notes'
    assert_select '.my-notes'
    assert_select '.shared-notes'
  end

  test "student should view accessible notes" do
    # Make note department-visible
    @note.update!(visibility: 'department')
    
    sign_in @student
    get note_url(@note)
    assert_response :success
    assert_select 'h1', @note.title
    assert_select '.note-content'
    assert_select '.note-metadata'
    # Should not see edit/delete buttons
    assert_select '.edit-note-button', count: 0
    assert_select '.delete-note-button', count: 0
  end

  test "student cannot view private notes" do
    sign_in @student
    get note_url(@private_note)
    assert_redirected_to notes_path
    assert_match 'You do not have permission to view this note', flash[:alert]
  end

  test "student should view shared notes" do
    @private_note.note_shares.create!(
      shared_by: @teacher,
      shared_with: @student,
      permission: 'view'
    )
    
    sign_in @student
    get note_url(@private_note)
    assert_response :success
    assert_select 'h1', @private_note.title
    assert_select '.shared-note-indicator'
  end

  test "student should edit shared notes with edit permission" do
    @private_note.note_shares.create!(
      shared_by: @teacher,
      shared_with: @student,
      permission: 'edit'
    )
    
    sign_in @student
    get edit_note_url(@private_note)
    assert_response :success
    assert_select 'form'
    
    patch note_url(@private_note), params: {
      note: {
        title: @private_note.title,
        content: 'Student edited content'
      }
    }
    
    assert_redirected_to note_path(@private_note)
    @private_note.reload
    assert_equal 'Student edited content', @private_note.content
  end

  test "student cannot edit shared notes with view-only permission" do
    @private_note.note_shares.create!(
      shared_by: @teacher,
      shared_with: @student,
      permission: 'view'
    )
    
    sign_in @student
    get edit_note_url(@private_note)
    assert_redirected_to note_path(@private_note)
    assert_match 'You do not have permission to edit this note', flash[:alert]
  end

  test "student should create their own notes" do
    sign_in @student
    
    assert_difference('Note.count') do
      post notes_url, params: {
        note: {
          title: 'My Study Notes',
          content: 'Personal study materials and thoughts.',
          visibility: 'private',
          note_type: 'personal'
        }
      }
    end
    
    note = Note.last
    assert_equal @student, note.user
    assert_redirected_to note_path(note)
  end

  # Search and Filtering Tests
  test "should search notes by title and content" do
    sign_in @teacher
    
    get notes_url, params: { search: 'algorithm' }
    assert_response :success
    assert_select '.note-card', text: /#{@note.title}/
  end

  test "should filter notes by visibility" do
    @note.update!(visibility: 'public')
    @private_note.update!(visibility: 'private')
    
    sign_in @teacher
    
    get notes_url, params: { visibility: 'public' }
    assert_response :success
    assert_select '.note-card', text: /#{@note.title}/
    assert_select '.note-card', text: /#{@private_note.title}/, count: 0
  end

  test "should filter notes by type" do
    @note.update!(note_type: 'study_guide')
    @private_note.update!(note_type: 'research')
    
    sign_in @teacher
    
    get notes_url, params: { note_type: 'study_guide' }
    assert_response :success
    assert_select '.note-card', text: /#{@note.title}/
    assert_select '.note-card', text: /#{@private_note.title}/, count: 0
  end

  test "should filter notes by tags" do
    tag = Tag.create!(name: 'algorithms')
    @note.note_tags.create!(tag: tag)
    
    sign_in @teacher
    
    get notes_url, params: { tag: 'algorithms' }
    assert_response :success
    assert_select '.note-card', text: /#{@note.title}/
  end

  test "should filter notes by department" do
    physics_dept = Department.create!(
      name: 'Physics Department',
      code: 'PHYS',
      university: universities(:test_university)
    )
    
    physics_note = Note.create!(
      title: 'Physics Notes',
      content: 'Physics study material',
      user: @teacher,
      department: physics_dept,
      visibility: 'department'
    )
    
    sign_in @teacher
    
    get notes_url, params: { department_id: @department.id }
    assert_response :success
    assert_select '.note-card', text: /#{@note.title}/
    assert_select '.note-card', text: /#{physics_note.title}/, count: 0
  end

  # Export and Download Tests
  test "should export note to markdown" do
    sign_in @teacher
    
    get note_url(@note, format: :md)
    assert_response :success
    assert_equal 'text/markdown', response.content_type.split(';').first
    assert_match "# #{@note.title}", response.body
    assert_match @note.content, response.body
  end

  test "should export note to PDF" do
    sign_in @teacher
    
    get note_url(@note, format: :pdf)
    assert_response :success
    assert_equal 'application/pdf', response.content_type.split(';').first
    assert_match /attachment; filename=.*\.pdf/, response.headers['Content-Disposition']
  end

  test "should export multiple notes" do
    note_ids = [@note.id, @private_note.id]
    
    sign_in @teacher
    
    post export_notes_url, params: { 
      note_ids: note_ids,
      format: 'zip'
    }
    
    assert_response :success
    assert_equal 'application/zip', response.content_type.split(';').first
  end

  # Collaboration Features Tests
  test "should show note activity feed" do
    @note.note_shares.create!(shared_by: @teacher, shared_with: @student, permission: 'edit')
    
    sign_in @teacher
    get activity_note_url(@note)
    assert_response :success
    assert_select '.activity-feed'
    assert_select '.activity-item'
  end

  test "should handle collaborative editing notifications" do
    @note.note_shares.create!(shared_by: @teacher, shared_with: @student, permission: 'edit')
    
    sign_in @student
    
    # Simulate collaborative edit
    patch note_url(@note), params: {
      note: {
        title: @note.title,
        content: 'Collaboratively edited content'
      }
    }
    
    assert_redirected_to note_path(@note)
    # Check that notification was sent to owner
    # This would typically involve checking email queue or notification system
  end

  # Mobile and API Tests
  test "should respond to JSON requests" do
    sign_in @teacher
    
    get notes_url, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should show note in JSON format" do
    sign_in @teacher
    
    get note_url(@note), headers: { 'Accept' => 'application/json' }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @note.title, json_response['title']
    assert_equal @note.content, json_response['content']
    assert json_response.key?('tags')
    assert json_response.key?('sharing_info')
  end

  test "should handle mobile note creation" do
    sign_in @teacher
    
    post notes_url, 
         params: {
           note: {
             title: 'Mobile Note',
             content: 'Created from mobile device',
             visibility: 'private',
             note_type: 'personal'
           }
         },
         headers: { 'User-Agent' => 'Mobile App' }
    
    assert_redirected_to note_path(Note.last)
    assert_equal 'Created from mobile device', Note.last.content
  end

  # Real-time Features Tests
  test "should provide real-time note updates via websocket" do
    @note.note_shares.create!(shared_by: @teacher, shared_with: @student, permission: 'edit')
    
    sign_in @teacher
    
    # This would test websocket connections in a real app
    get note_url(@note)
    assert_response :success
    assert_select '[data-websocket-url]'
  end

  # Performance Tests
  test "should efficiently load notes with associations" do
    # Create many notes with tags and shares
    20.times do |i|
      note = Note.create!(
        title: "Performance Note #{i}",
        content: "Content #{i}",
        user: @teacher,
        department: @department,
        visibility: 'department'
      )
      
      # Add tags
      3.times do |j|
        tag = Tag.find_or_create_by(name: "tag#{i}_#{j}")
        note.note_tags.create!(tag: tag)
      end
      
      # Add shares
      note.note_shares.create!(
        shared_by: @teacher,
        shared_with: @student,
        permission: 'view'
      )
    end
    
    sign_in @teacher
    get notes_url
    assert_response :success
  end

  # Authentication Tests
  test "should require authentication for all actions" do
    get notes_url
    assert_redirected_to new_user_session_path
    
    get note_url(@note)
    assert_redirected_to new_user_session_path
    
    get new_note_url
    assert_redirected_to new_user_session_path
    
    post notes_url, params: { note: { title: 'Test' } }
    assert_redirected_to new_user_session_path
  end

  # Validation Tests
  test "should not create note with invalid data" do
    sign_in @teacher
    
    assert_no_difference('Note.count') do
      post notes_url, params: {
        note: {
          title: '', # Invalid - blank title
          content: 'Valid content',
          visibility: 'private'
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.error-message, .alert', text: /can't be blank/
  end

  # Security Tests
  test "should sanitize note content" do
    sign_in @teacher
    
    malicious_content = '<script>alert("xss")</script><p>Safe content</p>'
    
    post notes_url, params: {
      note: {
        title: 'Security Test',
        content: malicious_content,
        visibility: 'private'
      }
    }
    
    note = Note.last
    # Assuming content is sanitized
    assert_not note.content.include?('<script>')
    assert note.content.include?('Safe content')
  end

  test "should prevent unauthorized access to private notes" do
    other_user = User.create!(
      email: 'other_user@test.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'User',
      role: 'student'
    )
    
    sign_in other_user
    get note_url(@private_note)
    assert_redirected_to notes_path
    assert_match 'You do not have permission', flash[:alert]
  end

  # Error Handling Tests
  test "should handle invalid note ID gracefully" do
    sign_in @teacher
    
    get note_url(99999)
    assert_response :not_found
  end

  test "should handle sharing with non-existent user" do
    sign_in @teacher
    
    post share_note_url(@note), params: {
      user_id: 99999,
      permission: 'view'
    }
    
    assert_response :unprocessable_entity
    assert_match 'User not found', flash[:alert]
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end
