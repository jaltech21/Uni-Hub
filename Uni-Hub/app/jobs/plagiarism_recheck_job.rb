class PlagiarismRecheckJob < ApplicationJob
  queue_as :plagiarism
  
  def perform(plagiarism_check_id)
    original_check = PlagiarismCheck.find(plagiarism_check_id)
    submission = original_check.submission
    
    # Only recheck if original case is still borderline and unresolved
    return unless original_check.similarity_percentage.between?(25, 40)
    return unless original_check.review_status == 'pending'
    
    # Perform new plagiarism check with enhanced detection
    detection_service = PlagiarismDetectionService.new(
      submission,
      detection_provider: 'enhanced',
      check_external_sources: true
    )
    
    new_check = detection_service.check_plagiarism
    
    # Compare results and update if significant change
    compare_and_update_results(original_check, new_check)
  end
  
  private
  
  def compare_and_update_results(original_check, new_check)
    similarity_difference = (new_check.similarity_percentage - original_check.similarity_percentage).abs
    
    # If significant change detected, notify instructor
    if similarity_difference > 10
      notify_instructor_of_recheck(original_check, new_check)
    end
    
    # Update original check with recheck information
    original_check.update!(
      recheck_performed: true,
      recheck_similarity: new_check.similarity_percentage,
      recheck_date: Time.current
    )
  end
  
  def notify_instructor_of_recheck(original_check, new_check)
    instructor = original_check.submission.assignment.course.instructor
    
    PlagiarismAlertMailer.recheck_completed(
      instructor,
      original_check,
      new_check
    ).deliver_now
  end
end