class PlagiarismCheck < ApplicationRecord
  belongs_to :submission
  
  validates :similarity_score, presence: true, numericality: { in: 0..100 }
  validates :check_status, presence: true, inclusion: { 
    in: %w[pending processing completed failed] 
  }
  
  # Scopes
  scope :completed, -> { where(check_status: 'completed') }
  scope :high_similarity, -> { where('similarity_score >= 25') }
  scope :medium_similarity, -> { where('similarity_score >= 15 AND similarity_score < 25') }
  scope :low_similarity, -> { where('similarity_score < 15') }
  scope :flagged, -> { where('similarity_score >= 20') }
  scope :recent, -> { order(checked_at: :desc) }
  
  # Callbacks
  after_update :flag_submission_if_needed
  
  # Status methods
  def pending?
    check_status == 'pending'
  end
  
  def processing?
    check_status == 'processing'
  end
  
  def completed?
    check_status == 'completed'
  end
  
  def failed?
    check_status == 'failed'
  end
  
  # Similarity assessment
  def similarity_level
    case similarity_score
    when 0..10
      'low'
    when 11..24
      'medium'
    when 25..49
      'high'
    else
      'very_high'
    end
  end
  
  def flagged?
    similarity_score >= 20
  end
  
  def requires_attention?
    flagged? || sources_found.any? { |source| source['confidence'] > 0.8 }
  end
  
  # Source analysis
  def primary_sources
    return [] unless sources_found.present?
    
    sources_found.select { |source| source['similarity_percentage'] > 10 }
                 .sort_by { |source| -source['similarity_percentage'] }
  end
  
  def total_unique_sources
    sources_found&.length || 0
  end
  
  def highest_similarity_source
    return nil unless sources_found.present?
    
    sources_found.max_by { |source| source['similarity_percentage'] }
  end
  
  # Flagged sections analysis
  def flagged_sections_count
    flagged_sections&.length || 0
  end
  
  def flagged_text_percentage
    return 0 unless flagged_sections.present? && submission.content.present?
    
    total_flagged_chars = flagged_sections.sum { |section| section['length'] || 0 }
    total_chars = submission.content.length
    
    return 0 if total_chars.zero?
    
    (total_flagged_chars.to_f / total_chars * 100).round(1)
  end
  
  def most_problematic_sections
    return [] unless flagged_sections.present?
    
    flagged_sections.select { |section| section['similarity'] > 80 }
                   .sort_by { |section| -section['similarity'] }
                   .first(5)
  end
  
  # AI Analysis parsing
  def parsed_ai_analysis
    return {} unless ai_analysis.present?
    
    begin
      JSON.parse(ai_analysis)
    rescue JSON::ParserError
      { summary: ai_analysis }
    end
  end
  
  def ai_assessment
    parsed = parsed_ai_analysis
    parsed['assessment'] || parsed['summary'] || 'No AI assessment available'
  end
  
  def ai_recommendations
    parsed = parsed_ai_analysis
    parsed['recommendations'] || []
  end
  
  def ai_confidence_score
    parsed = parsed_ai_analysis
    parsed['confidence'] || 0.5
  end
  
  # Reporting methods
  def detailed_report
    {
      submission_id: submission.id,
      student_name: submission.user.name,
      assignment_title: submission.assignment.title,
      similarity_score: similarity_score,
      similarity_level: similarity_level,
      flagged: flagged?,
      total_sources: total_unique_sources,
      primary_sources: primary_sources.first(3),
      flagged_sections_count: flagged_sections_count,
      flagged_text_percentage: flagged_text_percentage,
      ai_assessment: ai_assessment,
      checked_at: checked_at,
      requires_attention: requires_attention?
    }
  end
  
  def generate_report_summary
    summary = []
    summary << "Similarity Score: #{similarity_score}% (#{similarity_level})"
    summary << "Sources Found: #{total_unique_sources}"
    summary << "Flagged Sections: #{flagged_sections_count}"
    
    if requires_attention?
      summary << "⚠️ Requires instructor attention"
    end
    
    summary.join(" | ")
  end
  
  # Actions
  def mark_reviewed_by_instructor!
    # Add a reviewed flag or timestamp if needed
    update_column(:instructor_reviewed_at, Time.current)
  end
  
  def escalate_to_administration!
    # Create notification for academic integrity issues
    NotificationService.create_notification(
      user: submission.assignment.user,
      title: 'High Plagiarism Score Detected',
      message: "Submission by #{submission.user.name} has #{similarity_score}% similarity",
      notification_type: 'plagiarism_alert',
      related_object: self
    )
    
    # Could also create academic integrity case
    # AcademicIntegrityCase.create_from_plagiarism_check(self)
  end
  
  # Class methods for analytics
  def self.average_similarity_score
    completed.average(:similarity_score)&.to_f&.round(1) || 0
  end
  
  def self.flagged_rate
    total = completed.count
    return 0 if total.zero?
    
    (flagged.count.to_f / total * 100).round(1)
  end
  
  def self.similarity_distribution
    completed.group_by(&:similarity_level).transform_values(&:count)
  end
  
  def self.performance_metrics
    {
      total_checks: completed.count,
      average_similarity: average_similarity_score,
      flagged_rate: flagged_rate,
      distribution: similarity_distribution,
      high_risk_submissions: flagged.count
    }
  end
  
  # Batch processing methods
  def self.process_batch(submissions)
    submissions.each do |submission|
      PlagiarismCheckJob.perform_later(submission.id)
    end
  end
  
  def self.recheck_flagged_submissions
    flagged.each do |check|
      PlagiarismCheckJob.perform_later(check.submission_id, recheck: true)
    end
  end
  
  private
  
  def flag_submission_if_needed
    return unless similarity_score_changed? && flagged?
    
    # Flag the submission for instructor review
    submission.update_column(:flagged_for_review, true)
    
    # Notify instructor if similarity is very high
    if similarity_score >= 40
      escalate_to_administration!
    end
  end
end