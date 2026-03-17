class ProgramCourse < ApplicationRecord
  belongs_to :campus_program
  belongs_to :course
  
  validates :course_type, presence: true,
            inclusion: { in: %w[required elective core prerequisite] }
  validates :credits, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :course_id, uniqueness: { scope: :campus_program_id }
  
  scope :required, -> { where(course_type: 'required') }
  scope :elective, -> { where(course_type: 'elective') }
  scope :core, -> { where(course_type: 'core') }
  scope :prerequisites, -> { where(course_type: 'prerequisite') }
  scope :by_type, ->(type) { where(course_type: type) }
  
  def required?
    required || course_type == 'required'
  end
  
  def elective?
    course_type == 'elective'
  end
  
  def core?
    course_type == 'core'
  end
end