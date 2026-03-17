class Submission < ApplicationRecord
  belongs_to :assignment
  belongs_to :user
  
  has_many :ai_grading_results, dependent: :destroy
  has_many :plagiarism_checks, dependent: :destroy # The student who submitted
  belongs_to :graded_by, class_name: 'User', optional: true # The teacher who graded

  # Active Storage for multiple file submissions
  has_many_attached :documents

  # Validations
  validates :documents, presence: true, on: :create
  validates :grade, numericality: { 
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: ->(submission) { submission.assignment.points }
  }, allow_nil: true
  validates :status, inclusion: { 
    in: %w[pending submitted graded],
    message: "%{value} is not a valid status" 
  }

  # Callbacks
  before_create :set_submitted_at
  after_update :set_graded_at, if: :saved_change_to_grade?

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :submitted, -> { where(status: 'submitted') }
  scope :graded, -> { where(status: 'graded') }
  scope :by_student, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(submitted_at: :desc) }

  # Instance methods
  def late_submission?
    return false unless submitted_at
    submitted_at > assignment.due_date
  end

  def percentage_grade
    return nil unless grade && assignment.points > 0
    
    ((grade.to_f / assignment.points) * 100).round(2)
  end

  def letter_grade
    pct = percentage_grade
    return nil unless pct

    case pct
    when 90..100 then 'A'
    when 80...90 then 'B'
    when 70...80 then 'C'
    when 60...70 then 'D'
    else 'F'
    end
  end

  def grade_with_feedback?
    grade.present? && feedback.present?
  end

  private

  def set_submitted_at
    self.submitted_at = Time.current
    self.status = 'submitted'
  end

  def set_graded_at
    self.graded_at = Time.current
    self.status = 'graded' if grade.present?
  end

  # Ransack allowlist for ActiveAdmin searches
  def self.ransackable_attributes(auth_object = nil)
    %w[id assignment_id user_id status grade submitted_at graded_at created_at updated_at].freeze
  end

  def self.ransackable_associations(auth_object = nil)
    %w[assignment user graded_by].freeze
  end
end
