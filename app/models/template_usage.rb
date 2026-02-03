class TemplateUsage < ApplicationRecord
  belongs_to :content_template
  belongs_to :user
  
  validates :used_at, presence: true
  validates :context, inclusion: { in: %w[direct_use template_creation assignment_creation note_creation quiz_creation] }
  
  scope :recent, -> { order(used_at: :desc) }
  scope :by_context, ->(context) { where(context: context) }
  scope :this_month, -> { where(used_at: 1.month.ago..Time.current) }
  scope :this_week, -> { where(used_at: 1.week.ago..Time.current) }
  
  # Analytics methods
  def self.usage_stats_for_template(template)
    usages = where(content_template: template)
    
    {
      total_uses: usages.count,
      unique_users: usages.distinct.count(:user_id),
      this_month: usages.this_month.count,
      this_week: usages.this_week.count,
      by_context: usages.group(:context).count,
      recent_users: usages.includes(:user).recent.limit(10).map { |u| u.user.name }
    }
  end
  
  def self.popular_templates(limit = 10)
    joins(:content_template)
      .where(content_templates: { status: 'published' })
      .group(:content_template_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .includes(:content_template)
      .map(&:content_template)
  end
  
  def self.trending_templates(days = 7, limit = 10)
    joins(:content_template)
      .where(content_templates: { status: 'published' })
      .where(used_at: days.days.ago..Time.current)
      .group(:content_template_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .includes(:content_template)
      .map(&:content_template)
  end
end