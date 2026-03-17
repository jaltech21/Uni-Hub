class NoteDepartment < ApplicationRecord
  belongs_to :note
  belongs_to :department
  belongs_to :shared_by, class_name: 'User'
  
  validates :permission_level, inclusion: { in: %w[view edit manage] }
  validates :note_id, uniqueness: { scope: :department_id }
  
  PERMISSION_LEVELS = %w[view edit manage].freeze
end
