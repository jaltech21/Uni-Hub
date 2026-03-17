class AiUsageLog < ApplicationRecord
  belongs_to :user

  # Validations
  validates :action, presence: true
  validates :status, presence: true, inclusion: { in: %w[success failure rate_limited] }

  # Scopes
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failure') }
  scope :rate_limited, -> { where(status: 'rate_limited') }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', Time.current.beginning_of_week) }
  scope :this_month, -> { where('created_at >= ?', Time.current.beginning_of_month) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_provider, ->(provider) { where(provider: provider) }

  # Class methods for statistics
  def self.success_rate
    return 0 if count.zero?
    (successful.count.to_f / count * 100).round(2)
  end

  def self.average_processing_time
    average(:processing_time)&.round(2) || 0
  end

  def self.total_tokens_used
    sum(:tokens_used)
  end

  def self.stats_by_action
    group(:action).count
  end

  def self.daily_stats(days = 7)
    days.times.map do |i|
      date = i.days.ago.to_date
      {
        date: date,
        total: where('DATE(created_at) = ?', date).count,
        successful: where('DATE(created_at) = ? AND status = ?', date, 'success').count,
        failed: where('DATE(created_at) = ? AND status = ?', date, 'failure').count,
        rate_limited: where('DATE(created_at) = ? AND status = ?', date, 'rate_limited').count
      }
    end.reverse
  end

  # Instance methods
  def success?
    status == 'success'
  end

  def failure?
    status == 'failure'
  end

  def rate_limited?
    status == 'rate_limited'
  end
end
