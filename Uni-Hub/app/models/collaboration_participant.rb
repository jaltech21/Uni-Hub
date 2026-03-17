class CollaborationParticipant < ApplicationRecord
  belongs_to :cross_campus_collaboration
  belongs_to :user
  
  validates :role, presence: true,
            inclusion: { in: %w[lead co_lead collaborator advisor observer] }
  validates :status, presence: true,
            inclusion: { in: %w[active inactive] }
  validates :user_id, uniqueness: { scope: :cross_campus_collaboration_id }
  
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :by_role, ->(role) { where(role: role) }
  scope :leads, -> { where(role: ['lead', 'co_lead']) }
  
  def active?
    status == 'active'
  end
  
  def inactive?
    status == 'inactive'
  end
  
  def duration_days
    return nil unless joined_at
    end_date = left_at || Time.current
    ((end_date - joined_at) / 1.day).round
  end
end