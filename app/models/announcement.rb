class Announcement < ApplicationRecord
  # Associations
  belongs_to :department
  belongs_to :user
  
  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true
  validates :priority, presence: true, inclusion: { in: %w[low normal high urgent] }
  
  # Scopes
  scope :published, -> { where.not(published_at: nil).where('published_at <= ?', Time.current) }
  scope :draft, -> { where(published_at: nil) }
  scope :active, -> { published.where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { published.where('expires_at <= ?', Time.current) }
  scope :pinned, -> { where(pinned: true) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 WHEN 'low' THEN 4 END")) }
  scope :for_department, ->(department_id) { where(department_id: department_id) }
  
  # Class methods
  def self.PRIORITIES
    %w[low normal high urgent]
  end
  
  # Instance methods
  def published?
    published_at.present? && published_at <= Time.current
  end
  
  def draft?
    published_at.nil?
  end
  
  def active?
    published? && (expires_at.nil? || expires_at > Time.current)
  end
  
  def expired?
    published? && expires_at.present? && expires_at <= Time.current
  end
  
  def publish!
    update(published_at: Time.current)
  end
  
  def unpublish!
    update(published_at: nil)
  end
  
  def toggle_pin!
    update(pinned: !pinned)
  end
  
  def priority_badge_color
    case priority
    when 'urgent'
      'red'
    when 'high'
      'orange'
    when 'normal'
      'blue'
    when 'low'
      'gray'
    else
      'gray'
    end
  end
  
  def priority_icon
    case priority
    when 'urgent'
      '🚨'
    when 'high'
      '⚠️'
    when 'normal'
      'ℹ️'
    when 'low'
      '📌'
    else
      'ℹ️'
    end
  end
end
