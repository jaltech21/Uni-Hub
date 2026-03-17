class DiscussionPost < ApplicationRecord
  belongs_to :discussion
  belongs_to :user
  belongs_to :parent, class_name: 'DiscussionPost', optional: true
  has_many :replies, class_name: 'DiscussionPost', foreign_key: 'parent_id', dependent: :destroy
  
  # Validations
  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }
  validates :discussion_id, presence: true
  validates :user_id, presence: true
  
  # Scopes
  scope :top_level, -> { where(parent_id: nil) }
  scope :replies, -> { where.not(parent_id: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :for_discussion, ->(discussion_id) { where(discussion_id: discussion_id) }
  
  # Callbacks
  after_create :update_discussion_activity
  after_create :increment_user_posts_count
  
  # Instance methods
  def top_level?
    parent_id.nil?
  end
  
  def reply?
    parent_id.present?
  end
  
  def has_replies?
    replies.any?
  end
  
  def replies_count
    replies.count
  end
  
  def depth
    return 0 if top_level?
    
    depth = 1
    current_parent = parent
    while current_parent&.parent
      depth += 1
      current_parent = current_parent.parent
    end
    depth
  end
  
  def thread_root
    return self if top_level?
    
    root = self
    while root.parent
      root = root.parent
    end
    root
  end
  
  def can_reply?
    depth < 5 # Limit nesting depth
  end
  
  def formatted_content
    # Basic markdown-like formatting
    content.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
           .gsub(/\*(.*?)\*/, '<em>\1</em>')
           .gsub(/\n/, '<br>')
           .html_safe
  end
  
  private
  
  def update_discussion_activity
    discussion.touch(:updated_at)
  end
  
  def increment_user_posts_count
    # Could implement user statistics if needed
  end
end
