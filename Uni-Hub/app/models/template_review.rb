class TemplateReview < ApplicationRecord
  belongs_to :content_template
  belongs_to :user
  
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :review_text, length: { maximum: 1000 }
  validates :user_id, uniqueness: { scope: :content_template_id, message: "can only review a template once" }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :with_text, -> { where.not(review_text: [nil, '']) }
  scope :helpful, -> { where('helpful_votes > 0').order(helpful_votes: :desc) }
  
  before_save :sanitize_review_text
  after_create :update_template_rating_cache
  after_update :update_template_rating_cache
  after_destroy :update_template_rating_cache
  
  def helpful?
    helpful_votes > 0
  end
  
  def can_be_marked_helpful_by?(user)
    user != self.user && !user_marked_helpful?(user)
  end
  
  def user_marked_helpful?(user)
    # This would require a separate model to track who marked reviews as helpful
    # For now, we'll use a simple approach
    false # Placeholder
  end
  
  def mark_helpful!(user)
    return false if user == self.user
    
    increment!(:helpful_votes)
    # Here we would also create a record tracking that this user marked it helpful
    true
  end
  
  # Display methods
  def rating_stars
    '★' * rating + '☆' * (5 - rating)
  end
  
  def excerpt(length = 100)
    return '' if review_text.blank?
    
    review_text.length > length ? "#{review_text[0..length]}..." : review_text
  end
  
  # Class methods for statistics
  def self.average_rating
    average(:rating).to_f.round(1)
  end
  
  def self.rating_distribution
    group(:rating).count
  end
  
  def self.most_helpful(limit = 5)
    helpful.limit(limit)
  end
  
  private
  
  def sanitize_review_text
    return if review_text.blank?
    
    # Basic text sanitization
    self.review_text = review_text.strip
    # Remove potential harmful content
    self.review_text = ActionController::Base.helpers.sanitize(review_text)
  end
  
  def update_template_rating_cache
    # Update the cached rating on the template
    # This could be moved to a background job for performance
    template_reviews = content_template.template_reviews.where.not(rating: nil)
    avg_rating = template_reviews.any? ? template_reviews.average(:rating).to_f.round(1) : 0
    
    # If we add a cached_rating column to ContentTemplate, we'd update it here
    # content_template.update_column(:cached_rating, avg_rating)
  end
end