class AiGradingResult < ApplicationRecord
  belongs_to :submission
  belongs_to :grading_rubric
  belongs_to :reviewed_by, class_name: 'User', optional: true
  
  validates :ai_score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :confidence_score, presence: true, numericality: { in: 0..1 }
  validates :processing_status, presence: true, inclusion: { 
    in: %w[pending processing completed failed needs_review approved] 
  }
  
  # Scopes
  scope :pending_review, -> { where(reviewed_by: nil, processing_status: 'completed') }
  scope :approved, -> { where(processing_status: 'approved') }
  scope :needs_review, -> { where(processing_status: 'needs_review') }
  scope :high_confidence, -> { where('confidence_score >= 0.8') }
  scope :low_confidence, -> { where('confidence_score < 0.6') }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  before_save :determine_review_requirement
  after_update :notify_instructor_if_reviewed
  
  # Status methods
  def pending?
    processing_status == 'pending'
  end
  
  def processing?
    processing_status == 'processing'
  end
  
  def completed?
    processing_status == 'completed'
  end
  
  def failed?
    processing_status == 'failed'
  end
  
  def needs_review?
    processing_status == 'needs_review'
  end
  
  def approved?
    processing_status == 'approved'
  end
  
  def reviewed?
    reviewed_by.present?
  end
  
  # Grading methods
  def effective_score
    final_score.presence || ai_score
  end
  
  def score_difference
    return 0 unless final_score.present?
    (final_score - ai_score).abs
  end
  
  def score_difference_percentage
    return 0 unless final_score.present? && grading_rubric.total_points > 0
    (score_difference / grading_rubric.total_points * 100).round(1)
  end
  
  def confidence_level
    case confidence_score
    when 0.8..1.0
      'high'
    when 0.6..0.79
      'medium'
    else
      'low'
    end
  end
  
  def requires_review?
    confidence_score < 0.6 || 
    ai_score < (grading_rubric.total_points * 0.5) || # Below 50%
    ai_feedback.blank? ||
    flagged_for_manual_review?
  end
  
  def flagged_for_manual_review?
    # Check if submission has been flagged for plagiarism or other issues
    submission.plagiarism_checks.any? { |check| check.similarity_score > 25 } ||
    ai_feedback&.include?('requires human review') ||
    confidence_score < 0.4
  end
  
  # Review workflow
  def submit_for_review!
    update!(processing_status: 'needs_review')
    
    # Notify instructor
    NotificationService.create_notification(
      user: submission.assignment.user,
      title: 'AI Grading Requires Review',
      message: "Submission by #{submission.user.name} needs manual review",
      notification_type: 'grading_review',
      related_object: self
    )
  end
  
  def approve_ai_grade!(reviewer, notes = nil)
    update!(
      processing_status: 'approved',
      reviewed_by: reviewer,
      instructor_notes: notes,
      final_score: ai_score
    )
    
    # Update submission grade
    submission.update_grade!(effective_score, ai_feedback)
  end
  
  def override_ai_grade!(reviewer, new_score, notes)
    update!(
      processing_status: 'approved',
      reviewed_by: reviewer,
      final_score: new_score,
      instructor_notes: notes
    )
    
    # Update submission grade
    submission.update_grade!(new_score, combined_feedback)
  end
  
  def combined_feedback
    feedback_parts = []
    feedback_parts << ai_feedback if ai_feedback.present?
    feedback_parts << "Instructor Notes: #{instructor_notes}" if instructor_notes.present?
    feedback_parts.join("\n\n")
  end
  
  # AI Feedback parsing
  def parsed_feedback
    return {} unless ai_feedback.present?
    
    begin
      # Try to parse as JSON first
      JSON.parse(ai_feedback)
    rescue JSON::ParserError
      # If not JSON, try to extract structured feedback
      parse_text_feedback
    end
  end
  
  def criterion_scores
    parsed = parsed_feedback
    return {} unless parsed.is_a?(Hash)
    
    parsed['criterion_scores'] || parsed['scores'] || {}
  end
  
  def criterion_feedback
    parsed = parsed_feedback
    return {} unless parsed.is_a?(Hash)
    
    parsed['criterion_feedback'] || parsed['feedback'] || {}
  end
  
  def overall_feedback
    parsed = parsed_feedback
    return ai_feedback unless parsed.is_a?(Hash)
    
    parsed['overall_feedback'] || parsed['summary'] || ai_feedback
  end
  
  def suggestions
    parsed = parsed_feedback
    return [] unless parsed.is_a?(Hash)
    
    parsed['suggestions'] || parsed['improvements'] || []
  end
  
  # Analytics and reporting
  def accuracy_compared_to_instructor
    return nil unless final_score.present?
    
    difference = score_difference_percentage
    case difference
    when 0..5
      'excellent'
    when 6..10
      'good'
    when 11..20
      'fair'
    else
      'poor'
    end
  end
  
  def self.performance_metrics
    total_results = count
    return {} if total_results.zero?
    
    {
      total_graded: total_results,
      average_confidence: average(:confidence_score).to_f.round(3),
      high_confidence_rate: high_confidence.count.to_f / total_results * 100,
      needs_review_rate: needs_review.count.to_f / total_results * 100,
      average_processing_time: average_processing_time,
      accuracy_statistics: accuracy_statistics
    }
  end
  
  def self.average_processing_time
    completed_results = where.not(processed_at: nil, created_at: nil)
    return 0 if completed_results.empty?
    
    total_time = completed_results.sum do |result|
      (result.processed_at - result.created_at).to_i
    end
    
    (total_time.to_f / completed_results.count).round(2)
  end
  
  def self.accuracy_statistics
    reviewed_results = where.not(reviewed_by: nil, final_score: nil)
    return {} if reviewed_results.empty?
    
    accuracies = reviewed_results.map(&:accuracy_compared_to_instructor).compact
    
    {
      total_reviewed: reviewed_results.count,
      excellent_accuracy: accuracies.count('excellent'),
      good_accuracy: accuracies.count('good'),
      fair_accuracy: accuracies.count('fair'),
      poor_accuracy: accuracies.count('poor')
    }
  end
  
  private
  
  def determine_review_requirement
    if processing_status == 'completed' && requires_review?
      self.processing_status = 'needs_review'
    end
  end
  
  def notify_instructor_if_reviewed
    return unless reviewed_by_id_changed? && reviewed_by.present?
    
    # Notify instructor that review is complete
    NotificationService.create_notification(
      user: submission.assignment.user,
      title: 'AI Grading Review Complete',
      message: "Review completed for #{submission.user.name}'s submission",
      notification_type: 'grading_reviewed',
      related_object: self
    )
  end
  
  def parse_text_feedback
    # Simple text parsing to extract structured information
    feedback_hash = {}
    
    # Extract overall score if mentioned
    if ai_feedback.match(/total.+?(\d+(?:\.\d+)?)/i)
      feedback_hash['total_score'] = $1.to_f
    end
    
    # Extract suggestions
    suggestions_match = ai_feedback.match(/suggestions?:(.+?)(?:\n\n|\z)/im)
    if suggestions_match
      suggestions = suggestions_match[1].split(/[•\-\*]/).map(&:strip).reject(&:empty?)
      feedback_hash['suggestions'] = suggestions
    end
    
    # Store original text as overall feedback
    feedback_hash['overall_feedback'] = ai_feedback
    
    feedback_hash
  end
end