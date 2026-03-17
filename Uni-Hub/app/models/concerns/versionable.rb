module Versionable
  extend ActiveSupport::Concern
  
  included do
    has_many :content_versions, as: :versionable, dependent: :destroy
    
    # Callbacks
    after_create :create_initial_version
    before_update :create_version_on_change
    
    # Class variable to track if versioning should be skipped
    attr_accessor :skip_versioning
    
    # Virtual attribute for current version
    attr_accessor :current_version
  end
  
  class_methods do
    def with_versioning
      original_skip = Thread.current[:skip_versioning]
      Thread.current[:skip_versioning] = false
      yield
    ensure
      Thread.current[:skip_versioning] = original_skip
    end
    
    def without_versioning
      original_skip = Thread.current[:skip_versioning]
      Thread.current[:skip_versioning] = true
      yield
    ensure
      Thread.current[:skip_versioning] = original_skip
    end
  end
  
  # Instance methods
  def versioning_service
    @versioning_service ||= ContentVersioningService.new(self)
  end
  
  def create_version!(change_summary:, **options)
    versioning_service.create_version(change_summary: change_summary, **options)
  end
  
  def latest_version
    content_versions.order(version_number: :desc, patch_number: :desc).first
  end
  
  def published_version
    content_versions.published.order(version_number: :desc, patch_number: :desc).first
  end
  
  def draft_versions
    content_versions.draft.order(updated_at: :desc)
  end
  
  def current_draft
    draft_versions.first
  end
  
  def version_history(limit: 20)
    versioning_service.version_history(limit: limit)
  end
  
  def restore_to_version!(version_id)
    versioning_service.restore_to_version(version_id)
  end
  
  def compare_versions(version1_id, version2_id)
    versioning_service.compare_versions(version1_id, version2_id)
  end
  
  def auto_save(changes = {})
    return false if skip_versioning? || Thread.current[:skip_versioning]
    
    versioning_service.auto_save(changes)
  end
  
  def publish_draft!
    versioning_service.publish_draft
  end
  
  def has_unpublished_changes?
    latest = latest_version
    published = published_version
    
    return false unless latest && published
    
    latest.id != published.id
  end
  
  def version_count
    content_versions.count
  end
  
  def contributors
    User.joins(:content_versions)
        .where(content_versions: { versionable: self })
        .distinct
  end
  
  def restore_from_version!(version)
    # This method should be implemented by each model
    # to define how to restore content from a version
    raise NotImplementedError, "#{self.class} must implement restore_from_version!"
  end
  
  def apply_version!(version)
    # This method should be implemented by each model
    # to define how to apply a version's content to the current record
    raise NotImplementedError, "#{self.class} must implement apply_version!"
  end
  
  def update_content_from_version!(version)
    # Default implementation - can be overridden
    self.class.without_versioning do
      content_data = version.content_data
      
      # Update attributes from version content
      updateable_attributes = self.class.column_names & content_data.keys
      update_attributes = content_data.slice(*updateable_attributes)
      
      update!(update_attributes) if update_attributes.any?
    end
  end
  
  # Check if significant changes occurred
  def significant_changes?
    return false unless changed?
    
    significant_attributes = %w[title description content body instructions]
    (changed & significant_attributes).any?
  end
  
  # Get versionable attributes for comparison
  def versionable_attributes
    case self
    when Assignment
      %w[title description instructions due_date points_possible]
    when Note
      %w[title content tags folder_id]
    when Quiz
      %w[title description instructions questions time_limit]
    else
      %w[title description content]
    end
  end
  
  private
  
  def create_initial_version
    return if skip_versioning? || Thread.current[:skip_versioning]
    
    ContentVersion.create_initial_version(
      self,
      User.current || User.find_by(email: 'system@example.com'), # Fallback system user
      versioning_service.send(:extract_versionable_content)
    )
  rescue => e
    Rails.logger.error "Failed to create initial version for #{self.class.name}##{id}: #{e.message}"
  end
  
  def create_version_on_change
    return unless should_create_version?
    
    # Create version in after_update callback to ensure changes are persisted
    after_update_callback = -> {
      create_version!(
        change_summary: generate_change_summary,
        change_type: determine_change_type,
        status: 'published'
      )
    }
    
    # Store callback for execution after update
    @pending_version_callback = after_update_callback
  end
  
  def should_create_version?
    return false if skip_versioning? || Thread.current[:skip_versioning]
    return false unless changed?
    return false unless significant_changes?
    
    true
  end
  
  def skip_versioning?
    @skip_versioning == true
  end
  
  def generate_change_summary
    changed_attrs = changed_attributes.keys & versionable_attributes
    
    case changed_attrs.length
    when 0
      'Minor updates'
    when 1
      "Updated #{changed_attrs.first.humanize}"
    when 2
      "Updated #{changed_attrs.first.humanize} and #{changed_attrs.last.humanize}"
    else
      "Updated #{changed_attrs.first.humanize} and #{changed_attrs.length - 1} other fields"
    end
  end
  
  def determine_change_type
    changed_attrs = changed_attributes.keys
    
    return 'major' if changed_attrs.include?('title')
    return 'content' if (changed_attrs & %w[description content body instructions]).any?
    return 'structure' if (changed_attrs & %w[questions sections]).any?
    
    'minor'
  end
end