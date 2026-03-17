class AiGradingJob < ApplicationJob
  queue_as :grading
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(submission_id, rubric_id = nil, ai_provider = 'openai')
    submission = Submission.find(submission_id)
    
    # Use provided rubric or find appropriate one
    rubric = if rubric_id
               GradingRubric.find(rubric_id)
             else
               find_appropriate_rubric(submission)
             end
    
    return unless rubric&.ai_grading_enabled?
    
    # Check if already graded recently
    existing_result = submission.ai_grading_results
                               .where(grading_rubric: rubric)
                               .where('created_at > ?', 1.hour.ago)
                               .first
    
    return existing_result if existing_result&.completed?
    
    # Perform AI grading
    grading_service = AiGradingService.new(submission, rubric, ai_provider: ai_provider)
    result = grading_service.grade_submission
    
    # Send notification to instructor if review is required
    notify_instructor_if_needed(result)
    
    # Update submission with AI score if confidence is high enough
    update_submission_score(submission, result) if result.high_confidence?
    
    result
  end
  
  private
  
  def find_appropriate_rubric(submission)
    # Find AI-enabled rubric for this assignment
    assignment = submission.assignment
    
    # First, try assignment-specific rubrics
    rubric = assignment.grading_rubrics.ai_enabled.first
    return rubric if rubric
    
    # Then try course-level rubrics
    course_rubrics = assignment.course.grading_rubrics.ai_enabled
    
    # Find rubric with matching content type
    content_type = determine_content_type(assignment)
    matching_rubric = course_rubrics.where(content_type: content_type).first
    return matching_rubric if matching_rubric
    
    # Fall back to any AI-enabled rubric in the course
    course_rubrics.first
  end
  
  def determine_content_type(assignment)
    # Determine content type based on assignment characteristics
    title_lower = assignment.title.downcase
    content_lower = assignment.content&.downcase || ''
    
    return 'essay' if title_lower.include?('essay') || content_lower.include?('essay')
    return 'quiz' if assignment.is_a?(Quiz) || title_lower.include?('quiz')
    return 'project' if title_lower.include?('project') || content_lower.include?('project')
    return 'homework' if title_lower.include?('homework') || title_lower.include?('hw')
    
    'general'
  end
  
  def notify_instructor_if_needed(result)
    return unless result.requires_review?
    
    instructor = result.submission.assignment.course.instructor
    return unless instructor
    
    AiGradingNotificationMailer.review_required(
      instructor,
      result
    ).deliver_now
    
    # Create in-app notification
    Notification.create!(
      user: instructor,
      title: 'AI Grading Review Required',
      message: "AI grading for #{result.submission.user.name}'s submission requires your review (Confidence: #{(result.confidence_score * 100).round}%)",
      notification_type: 'grading_review',
      related_object: result
    )
  end
  
  def update_submission_score(submission, result)
    # Only update if confidence is very high and no manual grade exists
    return if submission.grade.present?
    return unless result.confidence_score >= 0.85
    
    submission.update!(
      grade: result.ai_score,
      graded_at: Time.current,
      grader_notes: "Auto-graded by AI (Confidence: #{(result.confidence_score * 100).round}%)"
    )
  end
end