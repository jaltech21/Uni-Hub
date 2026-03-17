class QuizQuestion < ApplicationRecord
  belongs_to :quiz
  
  validates :question_text, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :question_type, presence: true, inclusion: { in: %w[multiple_choice true_false short_answer] }
  validates :correct_answer, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :points, numericality: { only_integer: true, greater_than: 0 }
  
  validate :validate_options_for_multiple_choice
  validate :validate_options_for_true_false
  
  scope :ordered, -> { order(:position) }
  scope :by_type, ->(type) { where(question_type: type) }
  
  after_create :update_quiz_total_questions
  after_destroy :update_quiz_total_questions
  
  # Check if answer is correct
  def correct?(answer)
    case question_type
    when 'multiple_choice', 'true_false'
      correct_answer.strip.downcase == answer.to_s.strip.downcase
    when 'short_answer'
      # Case-insensitive match for short answers
      correct_answer.strip.downcase == answer.to_s.strip.downcase
    end
  end
  
  # Get formatted options for display
  def formatted_options
    return [] unless question_type == 'multiple_choice'
    options.is_a?(Array) ? options : []
  end
  
  private
  
  def validate_options_for_multiple_choice
    if question_type == 'multiple_choice'
      if options.blank? || !options.is_a?(Array) || options.length < 2
        errors.add(:options, 'must have at least 2 options for multiple choice questions')
      elsif !options.include?(correct_answer)
        errors.add(:correct_answer, 'must be one of the options')
      end
    end
  end
  
  def validate_options_for_true_false
    if question_type == 'true_false'
      unless %w[true false True False].include?(correct_answer)
        errors.add(:correct_answer, 'must be "true" or "false" for true/false questions')
      end
    end
  end
  
  def update_quiz_total_questions
    quiz.update_total_questions!
  end
end
