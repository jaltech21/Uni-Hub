class QuizAttempt < ApplicationRecord
  belongs_to :quiz
  belongs_to :user
  
  validates :started_at, presence: true
  validate :one_active_attempt_per_user_per_quiz, on: :create
  
  scope :completed, -> { where.not(completed_at: nil) }
  scope :in_progress, -> { where(completed_at: nil) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Check if attempt is completed
  def completed?
    completed_at.present?
  end
  
  # Check if attempt is in progress
  def in_progress?
    !completed?
  end
  
  # Calculate elapsed time
  def elapsed_time
    return 0 unless started_at
    end_time = completed_at || Time.current
    ((end_time - started_at) / 60.0).round(2) # minutes
  end
  
  # Check if time limit exceeded
  def time_limit_exceeded?
    return false unless quiz.time_limit
    elapsed_time > quiz.time_limit
  end
  
  # Submit the quiz and calculate score
  def submit!(submitted_answers = {})
    return if completed?
    
    self.answers = submitted_answers
    self.completed_at = Time.current
    self.time_taken = (completed_at - started_at).to_i
    self.total_questions = quiz.quiz_questions.count
    
    calculate_score!
    save!
  end
  
  # Get answer for a specific question
  def answer_for(question_id)
    answers[question_id.to_s]
  end
  
  # Check if answer is correct
  def correct_answer?(question_id)
    question = quiz.quiz_questions.find_by(id: question_id)
    return false unless question
    
    user_answer = answer_for(question_id)
    question.correct?(user_answer)
  end
  
  # Get percentage score
  def percentage
    score || 0
  end
  
  # Get letter grade
  def letter_grade
    case percentage
    when 90..100 then 'A'
    when 80...90 then 'B'
    when 70...80 then 'C'
    when 60...70 then 'D'
    else 'F'
    end
  end
  
  # Check if passed (60% or higher)
  def passed?
    percentage >= 60
  end
  
  private
  
  def calculate_score!
    questions = quiz.quiz_questions
    return if questions.empty?
    
    correct = 0
    questions.each do |question|
      correct += 1 if correct_answer?(question.id)
    end
    
    self.correct_answers = correct
    self.score = (correct.to_f / questions.count * 100).round(2)
  end
  
  def one_active_attempt_per_user_per_quiz
    if QuizAttempt.where(quiz: quiz, user: user).in_progress.exists?
      errors.add(:base, 'You already have an active attempt for this quiz')
    end
  end
end
