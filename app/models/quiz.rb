class Quiz < ApplicationRecord
  include Versionable
  
  belongs_to :user
  belongs_to :note, optional: true
  belongs_to :department, optional: true
  has_many :quiz_questions, dependent: :destroy
  has_many :quiz_attempts, dependent: :destroy
  
  # Department sharing
  has_many :quiz_departments, dependent: :destroy
  has_many :shared_departments, through: :quiz_departments, source: :department
  has_many :content_sharing_histories, as: :shareable, dependent: :destroy
  
  validates :title, presence: true, length: { minimum: 3, maximum: 200 }
  validates :status, inclusion: { in: %w[draft published archived] }
  validates :difficulty, inclusion: { in: %w[easy medium hard] }
  validates :time_limit, numericality: { greater_than: 0, allow_nil: true }
  
  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_department, ->(department) { where(department: department) if department.present? }
  scope :recent, -> { order(created_at: :desc) }
  
  # Calculate average score for this quiz
  def average_score
    return 0 if quiz_attempts.completed.empty?
    quiz_attempts.completed.average(:score).to_f.round(2)
  end
  
  # Get total attempts
  def attempts_count
    quiz_attempts.completed.count
  end
  
  # Check if user has attempted this quiz
  def attempted_by?(user)
    quiz_attempts.where(user: user).completed.exists?
  end
  
  # Get user's best score
  def best_score_for(user)
    quiz_attempts.where(user: user).completed.maximum(:score) || 0
  end
  
  # Update total questions count
  def update_total_questions!
    update(total_questions: quiz_questions.count)
  end
  
  # Check if quiz is published
  def published?
    status == 'published'
  end
  
  # Check if quiz is draft
  def draft?
    status == 'draft'
  end
  
  # Check if quiz is archived
  def archived?
    status == 'archived'
  end
  
  # Publish the quiz
  def publish!
    update(status: 'published') if quiz_questions.any?
  end
  
  # Archive the quiz
  def archive!
    update(status: 'archived')
  end
  
  # Version control methods
  def restore_from_version!(version)
    content_data = version.content_data
    
    self.class.without_versioning do
      update!(
        title: content_data['title'],
        description: content_data['description'],
        instructions: content_data['instructions'],
        time_limit: content_data['time_limit'],
        difficulty: content_data['difficulty'] || difficulty
      )
      
      # Handle questions if present in version
      if content_data['questions'].present?
        quiz_questions.destroy_all
        content_data['questions'].each do |question_data|
          quiz_questions.create!(
            question_text: question_data['question_text'],
            question_type: question_data['question_type'],
            options: question_data['options'],
            correct_answer: question_data['correct_answer'],
            points: question_data['points'] || 1
          )
        end
        update_total_questions!
      end
    end
  end
  
  def apply_version!(version)
    restore_from_version!(version)
  end
  
  def versionable_attributes
    %w[title description instructions time_limit difficulty]
  end
end
