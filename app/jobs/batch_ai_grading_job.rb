class BatchAiGradingJob < ApplicationJob
  queue_as :grading
  
  def perform(course_id, assignment_ids = nil, ai_provider = 'openai')
    course = Course.find(course_id)
    assignments = assignment_ids ? course.assignments.where(id: assignment_ids) : course.assignments
    
    results_summary = {
      total_assignments: 0,
      total_submissions: 0,
      total_graded: 0,
      high_confidence: 0,
      needs_review: 0,
      failed: 0,
      average_confidence: 0.0
    }
    
    assignments.includes(:grading_rubrics, :submissions).each do |assignment|
      # Skip assignments without AI-enabled rubrics
      ai_rubric = assignment.grading_rubrics.ai_enabled.first
      next unless ai_rubric
      
      results_summary[:total_assignments] += 1
      
      # Get ungraded submissions
      ungraded_submissions = assignment.submissions
                                      .left_joins(:ai_grading_results)
                                      .where(ai_grading_results: { id: nil })
      
      results_summary[:total_submissions] += ungraded_submissions.count
      
      # Grade each submission
      ungraded_submissions.find_each do |submission|
        begin
          grading_service = AiGradingService.new(submission, ai_rubric, ai_provider: ai_provider)
          result = grading_service.grade_submission
          
          if result.completed?
            results_summary[:total_graded] += 1
            results_summary[:high_confidence] += 1 if result.high_confidence?
            results_summary[:needs_review] += 1 if result.requires_review?
          else
            results_summary[:failed] += 1
          end
          
        rescue => e
          Rails.logger.error "Batch AI grading failed for submission #{submission.id}: #{e.message}"
          results_summary[:failed] += 1
        end
      end
    end
    
    # Calculate average confidence
    if results_summary[:total_graded] > 0
      total_confidence = AiGradingResult.joins(submission: { assignment: :course })
                                       .where(courses: { id: course.id })
                                       .where('ai_grading_results.created_at > ?', 1.hour.ago)
                                       .sum(:confidence_score)
      
      results_summary[:average_confidence] = (total_confidence / results_summary[:total_graded] * 100).round(1)
    end
    
    # Send completion notification to course instructor
    notify_instructor_of_completion(course, results_summary)
    
    results_summary
  end
  
  private
  
  def notify_instructor_of_completion(course, results_summary)
    instructor = course.instructor
    return unless instructor
    
    AiGradingNotificationMailer.batch_grading_complete(
      instructor,
      course,
      results_summary
    ).deliver_now
    
    # Create in-app notification
    Notification.create!(
      user: instructor,
      title: 'Batch AI Grading Complete',
      message: "Graded #{results_summary[:total_graded]} submissions across #{results_summary[:total_assignments]} assignments",
      notification_type: 'batch_grading_complete',
      priority: 'medium'
    )
  end
end