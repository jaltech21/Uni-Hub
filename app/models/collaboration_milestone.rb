class CollaborationMilestone < ApplicationRecord
  belongs_to :cross_campus_collaboration
  
  validates :title, presence: true, length: { maximum: 255 }
  validates :status, presence: true,
            inclusion: { in: %w[pending in_progress completed cancelled] }
  validates :due_date, presence: true
  
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Date.current, ['completed', 'cancelled']) }
  scope :upcoming, ->(days = 7) { where('due_date BETWEEN ? AND ?', Date.current, days.days.from_now) }
  scope :by_status, ->(status) { where(status: status) }
  
  def completed?
    status == 'completed'
  end
  
  def overdue?
    due_date < Date.current && !completed?
  end
  
  def days_until_due
    (due_date - Date.current).to_i
  end
  
  def complete!
    update!(status: 'completed', completed_at: Time.current)
  end
end