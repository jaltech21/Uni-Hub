class TemplateFavorite < ApplicationRecord
  belongs_to :content_template
  belongs_to :user
  
  validates :user_id, uniqueness: { scope: :content_template_id, message: "can only favorite a template once" }
  validates :favorited_at, presence: true
  
  scope :recent, -> { order(favorited_at: :desc) }
  scope :this_month, -> { where(favorited_at: 1.month.ago..Time.current) }
  
  before_validation :set_favorited_at, on: :create
  
  # Class methods for analytics
  def self.popular_templates(limit = 10)
    joins(:content_template)
      .where(content_templates: { status: 'published' })
      .group(:content_template_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .includes(:content_template)
      .map(&:content_template)
  end
  
  def self.trending_favorites(days = 7, limit = 10)
    joins(:content_template)
      .where(content_templates: { status: 'published' })
      .where(favorited_at: days.days.ago..Time.current)
      .group(:content_template_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .includes(:content_template)
      .map(&:content_template)
  end
  
  def self.favorites_count_for(template)
    where(content_template: template).count
  end
  
  private
  
  def set_favorited_at
    self.favorited_at ||= Time.current
  end
end