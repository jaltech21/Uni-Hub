class Course < ApplicationRecord
  belongs_to :department
  
  # Associations
  has_many :program_courses, dependent: :destroy
  has_many :campus_programs, through: :program_courses
  has_many :course_schedules, dependent: :destroy
  has_many :assignments, dependent: :destroy
  
  validates :code, presence: true, length: { maximum: 20 }, 
            uniqueness: { scope: :department_id, case_sensitive: false }
  validates :name, presence: true, length: { maximum: 255 }
  validates :credits, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :duration_weeks, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 52 }
  validates :level, inclusion: { in: %w[freshman sophomore junior senior graduate] }, allow_blank: true
  validates :delivery_method, inclusion: { in: %w[in_person online hybrid] }
  validates :tuition_cost, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :max_students, numericality: { greater_than: 0 }, allow_blank: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_level, ->(level) { where(level: level) }
  scope :by_delivery, ->(method) { where(delivery_method: method) }
  scope :by_credits, ->(credits) { where(credits: credits) }
  scope :undergraduate, -> { where(level: %w[freshman sophomore junior senior]) }
  scope :graduate, -> { where(level: 'graduate') }
  scope :online, -> { where(delivery_method: 'online') }
  scope :in_person, -> { where(delivery_method: 'in_person') }
  scope :hybrid, -> { where(delivery_method: 'hybrid') }
  
  before_validation :normalize_code
  
  def full_code
    "#{department.code}-#{code}"
  end
  
  def full_name
    "#{full_code}: #{name}"
  end
  
  def undergraduate?
    %w[freshman sophomore junior senior].include?(level)
  end
  
  def graduate?
    level == 'graduate'
  end
  
  def online?
    delivery_method == 'online'
  end
  
  def has_prerequisites?
    prerequisites.present? && prerequisites.is_a?(Array) && prerequisites.any?
  end
  
  def prerequisite_courses
    return [] unless has_prerequisites?
    
    Course.joins(:department)
          .where(departments: { code: prerequisites.map { |p| p['dept_code'] } })
          .where(code: prerequisites.map { |p| p['course_code'] })
  end
  
  def add_prerequisite(department_code, course_code, required: true)
    prereqs = prerequisites || []
    prereqs << {
      dept_code: department_code,
      course_code: course_code,
      required: required
    }
    update!(prerequisites: prereqs)
  end
  
  def total_cost
    tuition_cost || 0
  end
  
  private
  
  def normalize_code
    self.code = code&.upcase&.strip
  end
end
