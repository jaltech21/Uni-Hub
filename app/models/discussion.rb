class Discussion < ApplicationRecord
  belongs_to :user
  has_many :discussion_posts, dependent: :destroy
  has_many :contributors, -> { distinct }, through: :discussion_posts, source: :user
  
  # Validations
  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :description, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :category, presence: true, inclusion: { 
    in: %w[general academic assignments projects help announcements social events] 
  }
  validates :status, presence: true, inclusion: { in: %w[open closed pinned archived] }
  
  # Scopes
  scope :open, -> { where(status: 'open') }
  scope :closed, -> { where(status: 'closed') }
  scope :pinned, -> { where(status: 'pinned') }
  scope :archived, -> { where(status: 'archived') }
  scope :active, -> { where(status: ['open', 'pinned']) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :recent, -> { order(updated_at: :desc, created_at: :desc) }
  scope :popular, -> { order(views_count: :desc, updated_at: :desc) }
  scope :with_activity, -> { joins(:discussion_posts).group('discussions.id').order('MAX(discussion_posts.created_at) DESC') }
  
  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :increment_user_discussions_count
  after_update :update_last_activity, if: :saved_change_to_updated_at?
  
  # Class methods
  def self.categories
    %w[general academic assignments projects help announcements social events]
  end
  
  def self.statuses
    %w[open closed pinned archived]
  end
  
  # Instance methods
  def open?
    status == 'open'
  end
  
  def closed?
    status == 'closed'
  end
  
  def pinned?
    status == 'pinned'
  end
  
  def archived?
    status == 'archived'
  end
  
  def active?
    %w[open pinned].include?(status)
  end
  
  def last_post
    discussion_posts.order(:created_at).last
  end
  
  def posts_count
    discussion_posts.count
  end
  
  def replies_count
    discussion_posts.where.not(parent_id: nil).count
  end
  
  def increment_views!
    increment!(:views_count)
  end
  
  def close!
    update(status: 'closed')
  end
  
  def reopen!
    update(status: 'open')
  end
  
  def pin!
    update(status: 'pinned')
  end
  
  def unpin!
    update(status: 'open')
  end
  
  def archive!
    update(status: 'archived')
  end
  
  def category_color
    case category
    when 'general' then 'blue'
    when 'academic' then 'green'
    when 'assignments' then 'yellow'
    when 'projects' then 'purple'
    when 'help' then 'red'
    when 'announcements' then 'indigo'
    when 'social' then 'pink'
    when 'events' then 'teal'
    else 'gray'
    end
  end
  
  def category_icon
    case category
    when 'general' then 'fa-comments'
    when 'academic' then 'fa-graduation-cap'
    when 'assignments' then 'fa-tasks'
    when 'projects' then 'fa-project-diagram'
    when 'help' then 'fa-question-circle'
    when 'announcements' then 'fa-bullhorn'
    when 'social' then 'fa-users'
    when 'events' then 'fa-calendar-event'
    else 'fa-comment'
    end
  end
  
  private
  
  def set_defaults
    self.status ||= 'open'
    self.views_count ||= 0
  end
  
  def increment_user_discussions_count
    # Could implement user statistics if needed
  end
  
  def update_last_activity
    touch(:updated_at)
  end
end
