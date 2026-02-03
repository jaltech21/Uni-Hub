class UserDepartment < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :department
  belongs_to :invited_by, class_name: 'User', optional: true

  # Validations
  validates :user_id, presence: true
  validates :department_id, presence: true
  validates :user_id, uniqueness: { scope: :department_id, message: "is already assigned to this department" }
  validates :role, inclusion: { in: %w[member teacher admin], message: "%{value} is not a valid role" }
  validates :status, inclusion: { in: %w[active inactive pending], message: "%{value} is not a valid status" }
  
  # Callbacks
  before_create :set_joined_at
  before_update :set_left_at, if: :became_inactive?
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :pending, -> { where(status: 'pending') }
  scope :members, -> { where(role: 'member') }
  scope :teachers, -> { where(role: 'teacher') }
  scope :admins, -> { where(role: 'admin') }
  scope :recent, -> { order(joined_at: :desc) }
  
  # Ensure only tutors can have multiple departments
  validate :user_must_be_tutor_for_multiple_departments

  # Instance methods
  def activate!
    update(status: 'active', joined_at: joined_at || Time.current, left_at: nil)
  end
  
  def deactivate!
    update(status: 'inactive', left_at: Time.current)
  end
  
  def active?
    status == 'active'
  end
  
  def inactive?
    status == 'inactive'
  end
  
  def pending?
    status == 'pending'
  end
  
  def duration
    return nil unless joined_at
    end_time = left_at || Time.current
    ((end_time - joined_at) / 1.day).to_i
  end

  private

  def user_must_be_tutor_for_multiple_departments
    return unless user.present?
    
    # Students and regular users should use the department_id column, not this join table
    # Only tutors/teachers/admins should use this for multiple department assignments
    unless user.has_role?('tutor', 'teacher', 'admin', 'super_admin')
      errors.add(:user, "must be a tutor, teacher, or admin to use multiple departments")
    end
  end
  
  def set_joined_at
    self.joined_at ||= Time.current
  end
  
  def became_inactive?
    status_changed? && status == 'inactive' && status_was == 'active'
  end
  
  def set_left_at
    self.left_at = Time.current
  end
end
