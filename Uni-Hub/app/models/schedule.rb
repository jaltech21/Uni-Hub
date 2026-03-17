class Schedule < ApplicationRecord
  belongs_to :user
  belongs_to :instructor, class_name: 'User', foreign_key: 'instructor_id', optional: true
  belongs_to :department, optional: true
  
  has_many :schedule_participants, dependent: :destroy
  has_many :participants, through: :schedule_participants, source: :user
  has_many :students, -> { where(schedule_participants: { role: 'student' }) }, through: :schedule_participants, source: :user
  
  has_many :enrollments, dependent: :destroy
  has_many :enrolled_students, through: :enrollments, source: :user
  has_many :active_enrollments, -> { where(status: 'active') }, class_name: 'Enrollment'
  has_many :active_students, through: :active_enrollments, source: :user
  
  has_many :assignments, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :course, presence: true
  validates :day_of_week, presence: true, inclusion: { in: 0..6 } # 0=Sunday, 6=Saturday
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :room, presence: true
  validate :end_time_after_start_time
  validate :no_time_conflicts, on: :create

  # Scopes
  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :for_instructor, ->(instructor_id) { where(instructor_id: instructor_id) }
  scope :by_department, ->(department) { where(department: department) if department.present? }
  scope :by_teacher, ->(teacher_id) { where(user_id: teacher_id) }
  scope :available_for_enrollment, -> { all }
  scope :recurring, -> { where(recurring: true) }
  scope :by_start_time, -> { order(:start_time) }
  scope :by_day_and_time, -> { order(:day_of_week, :start_time) }
  scope :active, -> { where('end_time >= ?', Time.current) }

  def self.ransackable_attributes(auth_object = nil)
    %w[id title description course day_of_week start_time end_time room instructor_id user_id recurring color created_at updated_at].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user instructor schedule_participants participants students].freeze
  end

  # Instance methods
  def day_name
    Date::DAYNAMES[day_of_week]
  end

  def formatted_time_range
    "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  def duration_in_minutes
    ((end_time - start_time) / 60).to_i
  end

  def duration_in_hours
    (duration_in_minutes / 60.0).round(1)
  end

  def conflicts_with?(other_schedule)
    return false if day_of_week != other_schedule.day_of_week
    return false if instructor_id != other_schedule.instructor_id
    
    # Check if time ranges overlap
    (start_time < other_schedule.end_time) && (end_time > other_schedule.start_time)
  end

  def participant_count
    schedule_participants.active.count
  end

  def student_count
    schedule_participants.active.students.count
  end
  
  def duration_minutes
    return 0 unless start_time && end_time
    ((end_time - start_time) / 60).to_i
  end

  def add_participant(user, role: 'student')
    schedule_participants.create(user: user, role: role)
  end

  def remove_participant(user)
    schedule_participants.find_by(user: user)&.destroy
  end

  def has_participant?(user)
    schedule_participants.exists?(user: user)
  end

  # Enrollment capacity management
  def has_capacity?
    true  # No capacity limits for now
  end

  def available_slots
    Float::INFINITY  # Unlimited capacity for now
  end

  def course_assignments
    assignments.order(due_date: :desc)
  end

  def enrollment_percentage
    0  # No capacity tracking for now
  end

  # Display methods
  def full_name
    "#{course_code} - #{title}"
  end

  def course_code
    course
  end

  def time_display
    "#{day_name} #{formatted_time_range}"
  end

  def location
    room
  end

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?
    
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end

  def no_time_conflicts
    return unless instructor_id.present? && day_of_week.present? && start_time.present? && end_time.present?
    
    conflicting = Schedule.where(instructor_id: instructor_id, day_of_week: day_of_week)
                         .where.not(id: id)
                         .where('start_time < ? AND end_time > ?', end_time, start_time)
    
    if conflicting.exists?
      errors.add(:base, "Schedule conflicts with another class for this instructor on #{day_name}")
    end
  end
end
