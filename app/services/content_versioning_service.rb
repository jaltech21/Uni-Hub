class ContentVersioningService
  include ActionView::Helpers::TextHelper
  
  def initialize(content_object, user = nil)
    @content = content_object
    @user = user || User.current
  end
  
  # Create a new version from the current content state
  def create_version(change_summary:, change_type: 'content', status: 'draft', **options)
    version_data = extract_versionable_content
    
    version = @content.content_versions.build(
      user: @user,
      content_data: version_data,
      change_summary: change_summary,
      change_type: change_type,
      status: status,
      metadata: generate_metadata,
      **options
    )
    
    # Calculate diff from previous version if exists
    if previous_version = latest_version
      version.diff_data = ContentDiffService.new(previous_version, version).generate_diff
    end
    
    if version.save
      # Update content object with version reference
      @content.update!(current_version: version) if @content.respond_to?(:current_version=)
      
      # Create activity log
      create_version_activity(version)
      
      # Send notifications if published
      notify_stakeholders(version) if version.published?
      
      version
    else
      raise ActiveRecord::RecordInvalid, version
    end
  end
  
  # Auto-save functionality for drafts
  def auto_save(content_changes = {})
    return unless should_auto_save?
    
    # Find or create draft version
    draft_version = find_or_create_draft_version
    
    # Update content data
    updated_content = draft_version.content_data.deep_merge(content_changes)
    
    draft_version.update!(
      content_data: updated_content,
      updated_at: Time.current
    )
    
    draft_version
  rescue => e
    Rails.logger.error "Auto-save failed for #{@content.class.name}##{@content.id}: #{e.message}"
    nil
  end
  
  # Restore content to a specific version
  def restore_to_version(version_id, create_backup: true)
    version = @content.content_versions.find(version_id)
    
    # Create backup of current state if requested
    if create_backup && current_content_changed?
      create_version(
        change_summary: "Backup before restore to #{version.version_tag}",
        change_type: 'patch',
        status: 'archived'
      )
    end
    
    # Restore content
    restored_version = version.restore!
    
    if restored_version
      @content.reload
      create_version_activity(restored_version, 'restored')
      restored_version
    else
      raise StandardError, "Failed to restore to version #{version.version_tag}"
    end
  end
  
  # Compare two versions
  def compare_versions(version1_id, version2_id)
    version1 = @content.content_versions.find(version1_id)
    version2 = @content.content_versions.find(version2_id)
    
    ContentDiffService.new(version1, version2).detailed_comparison
  end
  
  # Get version history with metadata
  def version_history(limit: 20, include_drafts: false)
    query = @content.content_versions.includes(:user, :parent_version)
    
    unless include_drafts
      query = query.where.not(status: 'draft')
    end
    
    versions = query.order(created_at: :desc).limit(limit)
    
    versions.map do |version|
      {
        id: version.id,
        version_tag: version.version_tag,
        status: version.status,
        change_type: version.change_type,
        change_summary: version.change_summary,
        author: {
          id: version.user.id,
          name: version.user.name,
          avatar_url: version.user.avatar.attached? ? version.user.avatar.url : nil
        },
        created_at: version.created_at,
        statistics: version.content_statistics,
        can_restore: version.can_restore?,
        is_current: version == latest_published_version
      }
    end
  end
  
  # Publish current draft version
  def publish_draft(approval_notes: nil)
    draft = current_draft_version
    return false unless draft
    
    if draft.publish!
      create_version_activity(draft, 'published')
      notify_stakeholders(draft)
      true
    else
      false
    end
  end
  
  # Create a branch from current version
  def create_branch(branch_name, from_version: nil)
    source_version = from_version || latest_published_version
    return false unless source_version
    
    branch_version = source_version.create_branch(branch_name, @user)
    
    create_version_activity(branch_version, 'branched')
    branch_version
  end
  
  # Merge branch back to main
  def merge_branch(branch_version_id, merge_strategy: 'auto')
    branch_version = @content.content_versions.find(branch_version_id)
    main_version = latest_published_version
    
    return false unless branch_version && main_version
    
    merged_version = main_version.merge_from!(branch_version, merge_strategy)
    
    if merged_version
      create_version_activity(merged_version, 'merged')
      merged_version
    else
      false
    end
  end
  
  # Get content changes summary
  def changes_summary(since: 1.week.ago)
    versions = @content.content_versions
                      .where('created_at >= ?', since)
                      .includes(:user)
                      .order(:created_at)
    
    {
      total_versions: versions.count,
      contributors: versions.group(:user_id).count.keys.count,
      change_types: versions.group(:change_type).count,
      recent_activity: versions.limit(10).map do |v|
        {
          version_tag: v.version_tag,
          author: v.user.name,
          summary: v.change_summary,
          created_at: v.created_at
        }
      end
    }
  end
  
  private
  
  def extract_versionable_content
    case @content
    when Assignment
      extract_assignment_content
    when Note
      extract_note_content
    when Quiz
      extract_quiz_content
    else
      extract_generic_content
    end
  end
  
  def extract_assignment_content
    {
      title: @content.title,
      description: @content.description,
      instructions: @content.instructions,
      due_date: @content.due_date,
      points_possible: @content.points_possible,
      submission_types: @content.submission_types,
      rubric_data: @content.rubric&.as_json,
      attachments: extract_attachments,
      settings: extract_assignment_settings
    }
  end
  
  def extract_note_content
    {
      title: @content.title,
      content: @content.content,
      tags: @content.tags,
      folder_id: @content.folder_id,
      visibility: @content.visibility,
      attachments: extract_attachments
    }
  end
  
  def extract_quiz_content
    {
      title: @content.title,
      description: @content.description,
      instructions: @content.instructions,
      questions: @content.questions.as_json,
      time_limit: @content.time_limit,
      attempts_allowed: @content.attempts_allowed,
      settings: extract_quiz_settings
    }
  end
  
  def extract_generic_content
    content_hash = {}
    
    # Extract common attributes
    %w[title description content body instructions].each do |attr|
      content_hash[attr] = @content.send(attr) if @content.respond_to?(attr)
    end
    
    content_hash[:attachments] = extract_attachments if @content.respond_to?(:attachments)
    content_hash
  end
  
  def extract_attachments
    return [] unless @content.respond_to?(:attachments)
    
    @content.attachments.map do |attachment|
      {
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        checksum: attachment.checksum,
        created_at: attachment.created_at
      }
    end
  end
  
  def extract_assignment_settings
    {
      auto_grade: @content.respond_to?(:auto_grade) ? @content.auto_grade : false,
      peer_review: @content.respond_to?(:peer_review) ? @content.peer_review : false,
      group_assignment: @content.respond_to?(:group_assignment) ? @content.group_assignment : false
    }
  end
  
  def extract_quiz_settings
    {
      shuffle_questions: @content.respond_to?(:shuffle_questions) ? @content.shuffle_questions : false,
      show_correct_answers: @content.respond_to?(:show_correct_answers) ? @content.show_correct_answers : true,
      one_question_at_a_time: @content.respond_to?(:one_question_at_a_time) ? @content.one_question_at_a_time : false
    }
  end
  
  def generate_metadata
    {
      content_type: @content.class.name,
      content_id: @content.id,
      user_agent: @user&.current_sign_in_ip || 'system',
      timestamp: Time.current.iso8601,
      word_count: calculate_word_count,
      character_count: calculate_character_count
    }
  end
  
  def calculate_word_count
    text_content = extract_text_for_analysis
    text_content.split.length
  end
  
  def calculate_character_count
    text_content = extract_text_for_analysis
    text_content.length
  end
  
  def extract_text_for_analysis
    content_fields = %w[title description content body instructions]
    text_parts = content_fields.map { |field| @content.send(field) if @content.respond_to?(field) }.compact
    
    # Strip HTML tags
    text = text_parts.join(' ')
    ActionView::Base.full_sanitizer.sanitize(text)
  end
  
  def latest_version
    @content.content_versions.order(version_number: :desc, patch_number: :desc).first
  end
  
  def latest_published_version
    @content.content_versions.published.order(version_number: :desc, patch_number: :desc).first
  end
  
  def current_draft_version
    @content.content_versions.draft.order(updated_at: :desc).first
  end
  
  def find_or_create_draft_version
    current_draft_version || create_version(
      change_summary: 'Auto-save draft',
      change_type: 'patch',
      status: 'draft'
    )
  end
  
  def should_auto_save?
    # Don't auto-save if there's been recent activity
    return false if @content.updated_at > 1.minute.ago
    
    # Don't auto-save if there's a recent draft
    return false if current_draft_version&.updated_at && current_draft_version.updated_at > 5.minutes.ago
    
    true
  end
  
  def current_content_changed?
    latest = latest_version
    return true unless latest
    
    current_content = extract_versionable_content
    latest.content_data != current_content
  end
  
  def create_version_activity(version, action = 'created')
    # This would integrate with an activity tracking system
    Rails.logger.info "Version #{version.version_tag} #{action} for #{@content.class.name}##{@content.id} by user #{@user&.id}"
    
    # You could create actual Activity records here if you have an activity tracking system
  end
  
  def notify_stakeholders(version)
    # This would send notifications to relevant users
    # Could be instructors, students, department admins, etc.
    Rails.logger.info "Notifying stakeholders about version #{version.version_tag}"
    
    # Implementation would depend on your notification system
  end
end