class Assignment < ApplicationRecord
  include Versionable
  
  belongs_to :user # The teacher who created the assignment
  belongs_to :schedule, optional: true # The course/class this assignment is for
  belongs_to :department, optional: true  # Primary department
  has_many :assignment_departments, dependent: :destroy  # For multi-department assignments
  has_many :additional_departments, through: :assignment_departments, source: :department
  has_many :submissions, dependent: :destroy
  has_many :submitted_by, through: :submissions, source: :user
  has_many :content_sharing_histories, as: :shareable, dependent: :destroy
  has_many :grading_rubrics, dependent: :destroy
  has_many :ai_grading_results, through: :submissions
  has_many :plagiarism_checks, through: :submissions
  
  # Active Storage attachments for assignment files (resources, instructions, etc.)
  has_many_attached :files

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :description, presence: true
  validates :due_date, presence: true
  validates :points, numericality: { greater_than_or_equal_to: 0 }
  validates :category, presence: true, inclusion: { 
    in: %w[homework project quiz exam],
    message: "%{value} is not a valid category" 
  }

  # Scopes for filtering assignments
  scope :visible_to_student, ->(student) {
    joins(schedule: :enrollments)
      .where(enrollments: { user_id: student.id, status: 'active' })
      .distinct
  }
  scope :for_schedule, ->(schedule_id) { where(schedule_id: schedule_id) }
  scope :for_course, ->(course_code) {
    joins(:schedule).where(schedules: { course_code: course_code })
  }
  scope :upcoming, -> { where('due_date >= ?', Time.current).order(due_date: :asc) }
  scope :overdue, -> { where('due_date < ?', Time.current) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_course, ->(course) { where(course_name: course) if course.present? }
  scope :by_department, ->(department) { where(department: department) if department.present? }
  scope :upcoming, -> { where('due_date > ?', Time.current).order(due_date: :asc) }
  scope :overdue, -> { where('due_date < ?', Time.current).order(due_date: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def overdue?
    due_date < Time.current
  end

  def submitted_count
    submissions.where.not(submitted_at: nil).count
  end

  def graded_count
    submissions.where.not(graded_at: nil).count
  end

  def pending_submissions_count
    submissions.where(submitted_at: nil).count
  end

  def average_grade
    graded = submissions.where.not(grade: nil)
    return 0 if graded.empty?
    
    (graded.sum(:grade).to_f / graded.count).round(2)
  end

  # Get all departments this assignment is assigned to
  def all_departments
    departments = []
    departments << department if department.present?
    departments + additional_departments.to_a
  end
  
  # Check if assignment is available to a specific department
  def available_to_department?(dept)
    return false if dept.nil?
    all_departments.include?(dept)
  end
  
  # Assign to additional departments
  def assign_to_departments(*departments)
    departments.flatten.each do |dept|
      assignment_departments.find_or_create_by(department: dept) unless dept == department
    end
  end

  # Ransack allowlist for searchable attributes used by Active Admin
  def self.ransackable_attributes(auth_object = nil)
    %w[id title description due_date user_id category course_name points created_at updated_at].freeze
  end

  # Version control methods
  def restore_from_version!(version)
    content_data = version.content_data
    
    self.class.without_versioning do
      update!(
        title: content_data['title'],
        description: content_data['description'],
        instructions: content_data['instructions'],
        due_date: content_data['due_date'],
        points: content_data['points_possible'] || content_data['points'],
        category: content_data['category'] || category
      )
    end
  end
  
  # Check if a specific student can see this assignment
  def visible_to?(student)
    return true if user == student # Teacher can see their own
    return false unless schedule
    schedule.enrollments.exists?(user_id: student.id, status: 'active')
  end
  
  # Get all enrolled students who should submit
  def enrolled_students
    return User.none unless schedule
    schedule.students.where(enrollments: { status: 'active' })
  end
  
  # Delegate course info from schedule
  delegate :title, :course_code, to: :schedule, prefix: :course, allow_nil: true
  
  def apply_version!(version)
    restore_from_version!(version)
  end
  
  def versionable_attributes
    %w[title description instructions due_date points category]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user submissions].freeze
  end
end
