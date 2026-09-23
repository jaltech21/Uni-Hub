class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :schedule
  
  validates :user_id, uniqueness: { 
    scope: :schedule_id, 
    message: "is already enrolled in this course" 
  }
  
  # Student can be enrolled in multiple active courses at a time
  validate :schedule_has_capacity, on: :create
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :for_semester, ->(year, semester) { 
    where(academic_year: year, semester: semester) 
  }
  
  # Set current academic period
  before_create :set_academic_period
  
  def activate!
    update(status: 'active')
  end
  
  def deactivate!
    update(status: 'inactive')
  end
  
  private
  
  def schedule_has_capacity
    if schedule && !schedule.has_capacity?
      errors.add(:base, "This course has reached maximum enrollment capacity")
    end
  end
  
  def set_academic_period
    self.academic_year ||= Time.current.year.to_s
    self.semester ||= calculate_current_semester
  end
  
  def calculate_current_semester
    month = Time.current.month
    case month
    when 1..5 then 'Spring'
    when 6..8 then 'Summer'
    when 9..12 then 'Fall'
    end
  end
end
