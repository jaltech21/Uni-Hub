class ProgramEnrollment < ApplicationRecord
  belongs_to :campus_program
  belongs_to :user
  
  validates :status, presence: true,
            inclusion: { in: %w[active withdrawn graduated suspended transferred] }
  validates :enrollment_date, presence: true
  validates :user_id, uniqueness: { scope: :campus_program_id }
  
  scope :active, -> { where(status: 'active') }
  scope :graduated, -> { where(status: 'graduated') }
  scope :withdrawn, -> { where(status: 'withdrawn') }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent_enrollments, -> { where('enrollment_date >= ?', 30.days.ago) }
  
  def active?
    status == 'active'
  end
  
  def graduated?
    status == 'graduated'
  end
  
  def withdrawn?
    status == 'withdrawn'
  end
  
  def enrollment_duration_days
    end_date = graduation_date || withdrawal_date || Date.current
    (end_date - enrollment_date).to_i
  end
  
  def expected_graduation_passed?
    expected_graduation && expected_graduation < Date.current && !graduated?
  end
end