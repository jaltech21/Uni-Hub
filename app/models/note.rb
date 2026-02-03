class Note < ApplicationRecord
  include Versionable
  
  belongs_to :user
  belongs_to :folder, optional: true
  belongs_to :department, optional: true
  has_many :quizzes, dependent: :nullify
  has_many :note_tags, dependent: :destroy
  has_many :tags, through: :note_tags
  has_many :note_shares, dependent: :destroy
  has_many :shared_with_users, through: :note_shares, source: :shared_with
  
  # Department sharing
  has_many :note_departments, dependent: :destroy
  has_many :shared_departments, through: :note_departments, source: :department
  has_many :content_sharing_histories, as: :shareable, dependent: :destroy

  validates :title, presence: true, length: { minimum: 1, maximum: 200 }
  validates :content, presence: true

  scope :in_folder, ->(folder) { where(folder: folder) }
  scope :without_folder, -> { where(folder_id: nil) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_department, ->(department) { where(department: department) if department.present? }
  scope :tagged_with, ->(tag_name) { joins(:tags).where(tags: { name: tag_name.downcase }) }

  def self.ransackable_attributes(auth_object = nil)
    %w[id title user_id created_at updated_at folder_id].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user quizzes folder tags].freeze
  end
  
  # Search notes by keyword (simple search)
  def self.search(query)
    return all if query.blank?
    
    where("title ILIKE ? OR CAST(content AS TEXT) ILIKE ?", "%#{query}%", "%#{query}%")
  end
  
  # Get plain text content for AI processing
  def plain_text_content
    content.to_s
  end
  
  # Check if note has enough content for quiz generation
  def sufficient_for_quiz?
    plain_text_content.length >= 200
  end
  
  # Add tags by names (comma-separated or array)
  def tag_list=(names)
    tag_names = names.is_a?(String) ? names.split(',').map(&:strip) : names
    self.tags = tag_names.map { |name| Tag.find_or_create_by_name(name) }.compact
  end
  
  # Get tag names as comma-separated string
  def tag_list
    tags.pluck(:name).join(', ')
  end
  
  # Check if note is shared with a specific user
  def shared_with?(user)
    note_shares.exists?(shared_with: user)
  end
  
  # Check if user can edit this note
  def editable_by?(user)
    return true if self.user == user
    note_shares.exists?(shared_with: user, permission: 'edit')
  end
  
  # Check if user can view this note
  def viewable_by?(user)
    return true if self.user == user
    note_shares.exists?(shared_with: user)
  end
  
  # Share note with another user
  def share_with(user, permission: 'view')
    note_shares.create(shared_by: self.user, shared_with: user, permission: permission)
  end
  
  # Export to markdown
  def to_markdown
    "# #{title}\n\n#{plain_text_content}"
  end
  
  # Version control methods
  def restore_from_version!(version)
    content_data = version.content_data
    
    self.class.without_versioning do
      update!(
        title: content_data['title'],
        content: content_data['content'],
        folder_id: content_data['folder_id']
      )
      
      # Handle tags if present in version
      if content_data['tags'].present?
        # Clear existing tags and add version tags
        self.tags.clear
        content_data['tags'].each do |tag_name|
          tag = Tag.find_or_create_by(name: tag_name.downcase)
          self.tags << tag unless self.tags.include?(tag)
        end
      end
    end
  end
  
  def apply_version!(version)
    restore_from_version!(version)
  end
  
  def versionable_attributes
    %w[title content folder_id]
  end
end