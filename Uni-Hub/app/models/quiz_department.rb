class QuizDepartment < ApplicationRecord
  belongs_to :quiz
  belongs_to :department
  belongs_to :shared_by, class_name: 'User'
  
  validates :permission_level, inclusion: { in: %w[view take manage] }
  validates :quiz_id, uniqueness: { scope: :department_id }
  
  PERMISSION_LEVELS = %w[view take manage].freeze
end
