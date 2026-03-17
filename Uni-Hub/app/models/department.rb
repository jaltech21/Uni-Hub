class Department < ApplicationRecord
  # Associations
  belongs_to :university, optional: true
  has_many :users, dependent: :restrict_with_error  # Students with single department
  has_many :department_settings, dependent: :destroy
  has_many :users, through: :user_departments
  has_many :user_departments, dependent: :destroy
  has_many :grading_rubrics, dependent: :destroy  # Tutors with multiple departments
  has_many :tutors, through: :user_departments, source: :user
  has_many :teaching_users, through: :user_departments, source: :user  # Alias for tutors/teachers
  has_many :assignments, dependent: :restrict_with_error  # Primary assignments
  has_many :assignment_departments, dependent: :destroy  # Additional assignments
  has_many :shared_assignments, through: :assignment_departments, source: :assignment
  has_many :notes, dependent: :restrict_with_error
  has_many :quizzes, dependent: :restrict_with_error
  has_many :announcements, dependent: :destroy
  
  # Content sharing associations
  has_many :note_departments, dependent: :destroy
  has_many :shared_notes, through: :note_departments, source: :note
  has_many :quiz_departments, dependent: :destroy
  has_many :shared_quizzes, through: :quiz_departments, source: :quiz
  has_many :content_sharing_histories, dependent: :destroy
  
  # Settings
  has_one :department_setting, dependent: :destroy
  
  # Member history
  has_many :department_member_histories, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 10 }
  validates :code, uniqueness: { scope: :university_id, case_sensitive: false }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :ordered, -> { order(:name) }

  # Callbacks
  before_validation :normalize_code
  after_create :create_default_settings
  
  # Instance methods
  def settings
    department_setting || create_department_setting
  end
  
  def all_members
    # Get students directly assigned to this department
    students = users
    
    # Get tutors/teachers through user_departments
    teachers = teaching_users
    
    # Combine and return unique users
    (students + teachers).uniq
  end
  
  def active_members
    all_members.select { |u| u.user_departments.find_by(department: self)&.active? || u.department_id == id }
  end
  
  def member_count
    users.count + user_departments.active.count
  end

  private

  def normalize_code
    self.code = code.to_s.upcase.strip if code.present?
  end
  
  def create_default_settings
    create_department_setting unless department_setting
  end
end
