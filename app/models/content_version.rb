class ContentVersion < ApplicationRecord
  belongs_to :versionable, polymorphic: true
  belongs_to :user # Who made this version
  belongs_to :parent_version, class_name: 'ContentVersion', optional: true
  has_many :child_versions, class_name: 'ContentVersion', foreign_key: 'parent_version_id'
  
  # Scopes
  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :archived, -> { where(status: 'archived') }
  scope :recent, -> { order(created_at: :desc) }
  
  # Validations
  validates :version_number, presence: true, uniqueness: { scope: [:versionable_type, :versionable_id] }
  validates :content_data, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }
  validates :change_summary, presence: true, length: { maximum: 500 }
  
  # Enums
  enum :status, { draft: 0, published: 1, archived: 2 }
  enum :change_type, { 
    minor: 0, 
    major: 1, 
    patch: 2, 
    breaking: 3,
    content: 4,
    structure: 5,
    metadata: 6
  }
  
  # JSON columns (content_data, metadata, diff_data) are handled automatically by Rails
  
  # Callbacks
  before_create :set_version_number
  before_create :calculate_content_hash
  after_create :update_parent_content
  after_update :invalidate_cache
  
  # Instance methods
  def version_tag
    "v#{version_number}.#{patch_number || 0}"
  end
  
  def full_version_info
    {
      tag: version_tag,
      status: status,
      author: user.name,
      created: created_at,
      summary: change_summary,
      type: change_type
    }
  end
  
  def content_diff(compare_with = nil)
    return nil unless compare_with
    
    ContentDiffService.new(self, compare_with).generate_diff
  end
  
  def restore!
    return false unless can_restore?
    
    transaction do
      # Create new version from this one
      new_version = versionable.content_versions.create!(
        user: User.current, # Assuming current user tracking
        content_data: content_data.deep_dup,
        metadata: metadata.deep_dup,
        status: 'draft',
        change_summary: "Restored from #{version_tag}",
        change_type: 'major',
        parent_version: self
      )
      
      # Update the parent content
      versionable.restore_from_version!(new_version)
      
      new_version
    end
  end
  
  def can_restore?
    published? && versionable.present?
  end
  
  def calculate_changes_from_parent
    return {} unless parent_version
    
    ContentChangeCalculator.new(parent_version, self).calculate
  end
  
  def content_statistics
    return {} unless content_data.is_a?(Hash)
    
    {
      word_count: extract_text_content.split.length,
      character_count: extract_text_content.length,
      structure_elements: count_structure_elements,
      attachments: count_attachments,
      last_modified: updated_at
    }
  end
  
  def publish!
    return false unless draft?
    
    transaction do
      # Archive previous published version
      versionable.content_versions.published.update_all(status: 'archived')
      
      # Publish this version
      update!(status: 'published', published_at: Time.current)
      
      # Update parent content
      versionable.apply_version!(self)
      
      true
    end
  rescue => e
    Rails.logger.error "Failed to publish version #{id}: #{e.message}"
    false
  end
  
  def create_branch(branch_name, user = nil)
    new_version = dup
    new_version.assign_attributes(
      user: user || User.current,
      status: 'draft',
      branch_name: branch_name,
      parent_version: self,
      created_at: nil,
      updated_at: nil,
      version_number: nil # Will be set by callback
    )
    
    new_version.save!
    new_version
  end
  
  def merge_from!(source_version, merge_strategy = 'auto')
    merger = ContentMerger.new(self, source_version, merge_strategy)
    merger.perform_merge
  end
  
  # Class methods
  def self.create_initial_version(versionable, user, content_data = {})
    create!(
      versionable: versionable,
      user: user,
      content_data: content_data,
      status: 'published',
      change_summary: 'Initial version',
      change_type: 'major',
      version_number: 1,
      patch_number: 0
    )
  end
  
  def self.latest_published_for(versionable)
    where(versionable: versionable)
      .published
      .order(version_number: :desc, patch_number: :desc)
      .first
  end
  
  def self.version_history_for(versionable, limit = 10)
    where(versionable: versionable)
      .includes(:user, :parent_version)
      .order(created_at: :desc)
      .limit(limit)
  end
  
  private
  
  def set_version_number
    return if version_number.present?
    
    max_version = versionable.content_versions.maximum(:version_number) || 0
    
    if change_type.in?(['major', 'breaking'])
      self.version_number = max_version + 1
      self.patch_number = 0
    else
      self.version_number = max_version
      current_patch = versionable.content_versions
                                .where(version_number: max_version)
                                .maximum(:patch_number) || 0
      self.patch_number = current_patch + 1
    end
  end
  
  def calculate_content_hash
    content_string = content_data.is_a?(Hash) ? content_data.to_json : content_data.to_s
    self.content_hash = Digest::SHA256.hexdigest(content_string)
  end
  
  def update_parent_content
    # Update the parent record with the latest content if this is published
    return unless published?
    
    versionable.update_content_from_version!(self) if versionable.respond_to?(:update_content_from_version!)
  end
  
  def invalidate_cache
    Rails.cache.delete("content_version_#{id}")
    Rails.cache.delete("content_history_#{versionable_type}_#{versionable_id}")
  end
  
  def extract_text_content
    return '' unless content_data.is_a?(Hash)
    
    text_fields = %w[title description content body instructions]
    text_content = text_fields.map { |field| content_data[field] }.compact.join(' ')
    
    # Strip HTML tags if present
    ActionView::Base.full_sanitizer.sanitize(text_content)
  end
  
  def count_structure_elements
    return 0 unless content_data.is_a?(Hash)
    
    structure_fields = %w[questions sections parts chapters]
    structure_fields.sum { |field| content_data[field]&.length || 0 }
  end
  
  def count_attachments
    return 0 unless content_data.is_a?(Hash)
    
    content_data['attachments']&.length || 0
  end
end