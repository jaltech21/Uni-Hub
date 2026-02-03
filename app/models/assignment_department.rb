class AssignmentDepartment < ApplicationRecord
  belongs_to :assignment
  belongs_to :department
  belongs_to :shared_by, class_name: 'User', optional: true

  # Validations
  validates :assignment_id, presence: true
  validates :department_id, presence: true
  validates :assignment_id, uniqueness: { scope: :department_id, message: "is already assigned to this department" }
  validates :permission_level, inclusion: { in: %w[view submit manage] }
  
  PERMISSION_LEVELS = %w[view submit manage].freeze
end
