class ScheduleParticipant < ApplicationRecord
  belongs_to :schedule
  belongs_to :user

  validates :schedule_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :schedule_id, message: "is already enrolled in this schedule" }
  validates :role, inclusion: { in: %w[student teacher], message: "%{value} is not a valid role" }

  scope :active, -> { where(active: true) }
  scope :students, -> { where(role: 'student') }
  scope :teachers, -> { where(role: 'teacher') }

  def self.ransackable_attributes(auth_object = nil)
    %w[id schedule_id user_id role active created_at updated_at].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[schedule user].freeze
  end
end
