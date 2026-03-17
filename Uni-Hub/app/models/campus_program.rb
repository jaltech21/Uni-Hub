class CampusProgram < ApplicationRecord
  belongs_to :campus
  belongs_to :department
  belongs_to :program_director, class_name: 'User', optional: true
  
  # Associations
  has_many :program_enrollments, dependent: :destroy
  has_many :students, through: :program_enrollments, source: :user
  has_many :program_courses, dependent: :destroy
  has_many :courses, through: :program_courses
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :code, presence: true, length: { maximum: 20 }, 
            uniqueness: { scope: :campus_id, case_sensitive: false }
  validates :degree_level, presence: true, 
            inclusion: { in: %w[certificate associate bachelor master doctoral] }
  validates :duration_months, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 120 }
  validates :credits_required, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 300 }
  validates :delivery_method, 
            inclusion: { in: %w[on_campus online hybrid] }, allow_blank: true
  validates :tuition_per_credit, 
            numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :max_enrollment, :current_enrollment, 
            numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :current_enrollment, 
            numericality: { less_than_or_equal_to: :max_enrollment }, 
            if: -> { max_enrollment.present? && current_enrollment.present? }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_level, ->(level) { where(degree_level: level) }
  scope :by_delivery, ->(method) { where(delivery_method: method) }
  scope :accepting_applications, -> { where('max_enrollment IS NULL OR current_enrollment < max_enrollment') }
  scope :full_capacity, -> { where('max_enrollment IS NOT NULL AND current_enrollment >= max_enrollment') }
  scope :by_campus, ->(campus_id) { where(campus_id: campus_id) }
  scope :by_department, ->(dept_id) { where(department_id: dept_id) }
  scope :recently_added, -> { where('created_at >= ?', 30.days.ago) }
  
  # Callbacks
  before_validation :normalize_code
  before_save :update_enrollment_status
  after_create :initialize_program_data
  
  def full_name
    "#{degree_level.humanize} in #{name}"
  end
  
  def enrollment_status
    return 'open' if max_enrollment.nil?
    return 'full' if current_enrollment >= max_enrollment
    return 'limited' if current_enrollment >= (max_enrollment * 0.9)
    'open'
  end
  
  def enrollment_percentage
    return 0 if max_enrollment.nil? || max_enrollment.zero?
    ((current_enrollment.to_f / max_enrollment) * 100).round(2)
  end
  
  def spots_available
    return Float::INFINITY if max_enrollment.nil?
    [max_enrollment - current_enrollment, 0].max
  end
  
  def total_tuition_cost
    return nil if tuition_per_credit.nil?
    tuition_per_credit * credits_required
  end
  
  def estimated_completion_date(start_date = Date.current)
    start_date + duration_months.months
  end
  
  # Program outcomes management
  def add_outcome(outcome_description)
    outcomes = program_outcomes || []
    outcomes << {
      id: SecureRandom.uuid,
      description: outcome_description,
      created_at: Time.current.iso8601
    }
    update!(program_outcomes: outcomes)
  end
  
  def remove_outcome(outcome_id)
    return unless program_outcomes.is_a?(Array)
    
    updated_outcomes = program_outcomes.reject { |outcome| outcome['id'] == outcome_id }
    update!(program_outcomes: updated_outcomes)
  end
  
  def outcomes_list
    return [] unless program_outcomes.is_a?(Array)
    program_outcomes.map { |outcome| outcome['description'] }
  end
  
  # Accreditation management
  def accredited?
    accreditation_body.present? && last_accredited.present?
  end
  
  def accreditation_status
    return 'not_accredited' unless accredited?
    return 'expired' if last_accredited < 5.years.ago
    return 'expiring_soon' if next_review_date && next_review_date <= 6.months.from_now
    'current'
  end
  
  def days_until_review
    return nil unless next_review_date
    (next_review_date - Date.current).to_i
  end
  
  def accreditation_valid_until
    return nil unless last_accredited
    last_accredited + 5.years # Typical accreditation period
  end
  
  # Statistics and analytics
  def program_statistics
    {
      enrollment_rate: enrollment_percentage,
      completion_rate: calculate_completion_rate,
      employment_rate: calculate_employment_rate,
      average_gpa: calculate_average_gpa,
      retention_rate: calculate_retention_rate,
      graduation_rate: calculate_graduation_rate
    }
  end
  
  def financial_summary
    {
      total_tuition_revenue: calculate_tuition_revenue,
      cost_per_credit: tuition_per_credit || 0,
      total_program_cost: total_tuition_cost || 0,
      revenue_per_student: total_tuition_cost || 0
    }
  end
  
  # Course management
  def required_courses
    program_courses.where(course_type: 'required')
  end
  
  def elective_courses
    program_courses.where(course_type: 'elective')
  end
  
  def core_courses
    program_courses.where(course_type: 'core')
  end
  
  def add_course(course, course_type: 'required', credits: nil)
    program_courses.create!(
      course: course,
      course_type: course_type,
      credits: credits || course.credits,
      required: course_type == 'required'
    )
  end
  
  # Student management
  def enroll_student(user)
    return false if enrollment_status == 'full'
    
    enrollment = program_enrollments.create!(
      user: user,
      enrollment_date: Date.current,
      status: 'active',
      expected_graduation: estimated_completion_date
    )
    
    increment_enrollment! if enrollment.persisted?
    enrollment
  end
  
  def withdraw_student(user)
    enrollment = program_enrollments.find_by(user: user, status: 'active')
    return false unless enrollment
    
    enrollment.update!(status: 'withdrawn', withdrawal_date: Date.current)
    decrement_enrollment!
    true
  end
  
  def graduate_student(user)
    enrollment = program_enrollments.find_by(user: user, status: 'active')
    return false unless enrollment
    
    enrollment.update!(
      status: 'graduated', 
      graduation_date: Date.current,
      final_gpa: calculate_student_gpa(user)
    )
    decrement_enrollment!
    true
  end
  
  # Reporting methods
  def enrollment_by_semester
    program_enrollments.group_by_month(:enrollment_date).count
  end
  
  def graduation_by_semester
    program_enrollments.where(status: 'graduated')
                      .group_by_month(:graduation_date)
                      .count
  end
  
  def students_by_status
    program_enrollments.group(:status).count
  end
  
  # Program comparison
  def similar_programs(limit: 5)
    CampusProgram.where(degree_level: degree_level)
                 .where.not(id: id)
                 .joins(:campus)
                 .where(campuses: { university_id: campus.university_id })
                 .limit(limit)
  end
  
  def benchmark_metrics
    similar = similar_programs
    return {} if similar.empty?
    
    {
      avg_enrollment: similar.average(:current_enrollment)&.round(2),
      avg_tuition: similar.average(:tuition_per_credit)&.round(2),
      avg_duration: similar.average(:duration_months)&.round(1),
      avg_credits: similar.average(:credits_required)&.round(1)
    }
  end
  
  private
  
  def normalize_code
    self.code = code&.upcase&.strip
  end
  
  def update_enrollment_status
    # This could trigger notifications or other business logic
    if current_enrollment_changed? && enrollment_status == 'full'
      # Notify program director about full capacity
      notify_full_capacity if program_director
    end
  end
  
  def initialize_program_data
    # Set default program outcomes if none provided
    if program_outcomes.blank?
      default_outcomes = generate_default_outcomes
      update_column(:program_outcomes, default_outcomes)
    end
    
    # Set default delivery method
    update_column(:delivery_method, 'on_campus') if delivery_method.blank?
  end
  
  def generate_default_outcomes
    case degree_level
    when 'certificate'
      [
        { id: SecureRandom.uuid, description: "Demonstrate competency in specialized skills", created_at: Time.current.iso8601 },
        { id: SecureRandom.uuid, description: "Apply knowledge in professional settings", created_at: Time.current.iso8601 }
      ]
    when 'bachelor'
      [
        { id: SecureRandom.uuid, description: "Demonstrate critical thinking and problem-solving skills", created_at: Time.current.iso8601 },
        { id: SecureRandom.uuid, description: "Communicate effectively in written and oral formats", created_at: Time.current.iso8601 },
        { id: SecureRandom.uuid, description: "Apply disciplinary knowledge to real-world situations", created_at: Time.current.iso8601 }
      ]
    else
      [
        { id: SecureRandom.uuid, description: "Conduct independent research", created_at: Time.current.iso8601 },
        { id: SecureRandom.uuid, description: "Demonstrate advanced analytical skills", created_at: Time.current.iso8601 }
      ]
    end
  end
  
  def increment_enrollment!
    increment!(:current_enrollment)
  end
  
  def decrement_enrollment!
    return if current_enrollment <= 0
    decrement!(:current_enrollment)
  end
  
  def notify_full_capacity
    # Placeholder for notification logic
    puts "Program #{name} has reached full capacity"
  end
  
  # Placeholder methods for statistics (would require additional models/data)
  def calculate_completion_rate
    85.0 # Placeholder
  end
  
  def calculate_employment_rate
    78.0 # Placeholder
  end
  
  def calculate_average_gpa
    3.2 # Placeholder
  end
  
  def calculate_retention_rate
    82.0 # Placeholder
  end
  
  def calculate_graduation_rate
    75.0 # Placeholder
  end
  
  def calculate_tuition_revenue
    return 0 unless tuition_per_credit && current_enrollment
    tuition_per_credit * credits_required * current_enrollment
  end
  
  def calculate_student_gpa(user)
    # Placeholder - would calculate from actual grades
    3.0
  end
end