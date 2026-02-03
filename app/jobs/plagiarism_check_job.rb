class PlagiarismCheckJob < ApplicationJob
  queue_as :plagiarism
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(submission_id, detection_provider = 'internal', force_recheck = false)
    submission = Submission.find(submission_id)
    
    # Check if already processed recently (unless forcing recheck)
    unless force_recheck
      recent_check = submission.plagiarism_checks
                              .where('created_at > ?', 24.hours.ago)
                              .where(processing_status: 'completed')
                              .first
      
      return recent_check if recent_check
    end
    
    # Perform plagiarism check
    detection_service = PlagiarismDetectionService.new(
      submission, 
      detection_provider: detection_provider,
      check_external_sources: should_check_external_sources?(submission)
    )
    
    result = detection_service.check_plagiarism
    
    # Send notifications if high similarity detected
    notify_stakeholders_if_needed(result)
    
    # Schedule follow-up actions if needed
    schedule_follow_up_actions(result)
    
    result
  end
  
  private
  
  def should_check_external_sources?(submission)
    # Check external sources for important assignments
    assignment = submission.assignment
    
    # Always check for high-stakes assignments
    return true if assignment.respond_to?(:high_stakes?) && assignment.high_stakes?
    
    # Check based on assignment type
    return true if assignment.is_a?(Essay) || assignment.title.downcase.include?('essay')
    return true if assignment.title.downcase.include?('research')
    return true if assignment.title.downcase.include?('paper')
    
    # Check based on course level (graduate courses always check)
    course = assignment.course
    return true if course.level == 'graduate'
    
    # Default to internal checking only for regular assignments
    false
  end
  
  def notify_stakeholders_if_needed(check)
    return unless check.requires_review?
    
    # Notify course instructor
    notify_instructor(check)
    
    # Notify academic integrity office if very high similarity
    if check.similarity_percentage > 70
      notify_academic_integrity_office(check)
    end
    
    # Notify student if policy requires transparency
    if transparency_required?(check)
      notify_student(check)
    end
  end
  
  def notify_instructor(check)
    instructor = check.submission.assignment.course.instructor
    return unless instructor
    
    PlagiarismAlertMailer.instructor_alert(
      instructor,
      check
    ).deliver_now
    
    # Create in-app notification
    Notification.create!(
      user: instructor,
      title: 'Plagiarism Detection Alert',
      message: plagiarism_notification_message(check),
      notification_type: 'plagiarism_alert',
      related_object: check,
      priority: check.similarity_percentage > 50 ? 'high' : 'medium'
    )
  end
  
  def notify_academic_integrity_office(check)
    # Find academic integrity coordinators
    integrity_coordinators = User.where(role: 'academic_integrity_coordinator')
    
    integrity_coordinators.each do |coordinator|
      PlagiarismAlertMailer.integrity_office_alert(
        coordinator,
        check
      ).deliver_now
      
      Notification.create!(
        user: coordinator,
        title: 'High Similarity Plagiarism Case',
        message: "Potential plagiarism case requires investigation: #{check.submission.user.name} - #{check.similarity_percentage}% similarity",
        notification_type: 'integrity_investigation',
        related_object: check,
        priority: 'high'
      )
    end
  end
  
  def notify_student(check)
    student = check.submission.user
    
    PlagiarismAlertMailer.student_notification(
      student,
      check
    ).deliver_now
    
    Notification.create!(
      user: student,
      title: 'Submission Review Required',
      message: 'Your recent submission has been flagged for similarity review. Please contact your instructor.',
      notification_type: 'submission_review',
      related_object: check
    )
  end
  
  def transparency_required?(check)
    # Check institutional policy for student notification
    course = check.submission.assignment.course
    institution = course.institution
    
    # Default policy: notify students of plagiarism checks
    institution&.plagiarism_transparency_enabled? != false
  end
  
  def plagiarism_notification_message(check)
    similarity = check.similarity_percentage
    student_name = check.submission.user.name
    assignment_title = check.submission.assignment.title
    
    message = "Plagiarism check completed for #{student_name}'s submission"
    message += " to \"#{assignment_title}\""
    message += " - #{similarity}% similarity detected"
    
    if check.flagged_sections_data.any?
      flag_count = check.flagged_sections_data.length
      message += " (#{flag_count} flagged sections)"
    end
    
    message
  end
  
  def schedule_follow_up_actions(check)
    return unless check.requires_review?
    
    # Schedule escalation if not reviewed within timeframe
    EscalatePlagiarismCaseJob.set(wait: 3.days).perform_later(check.id)
    
    # Schedule recheck for borderline cases
    if check.similarity_percentage.between?(25, 40)
      PlagiarismRecheckJob.set(wait: 1.week).perform_later(check.id)
    end
  end
  
  # Class method for batch processing
  def self.batch_check_assignment(assignment_id, detection_provider = 'internal')
    assignment = Assignment.find(assignment_id)
    
    assignment.submissions.includes(:plagiarism_checks).find_each do |submission|
      # Skip if already checked recently
      next if submission.plagiarism_checks.where('created_at > ?', 24.hours.ago).exists?
      
      perform_later(submission.id, detection_provider)
    end
  end
  
  def self.batch_check_course(course_id, detection_provider = 'internal')
    course = Course.find(course_id)
    
    course.assignments.includes(submissions: :plagiarism_checks).find_each do |assignment|
      assignment.submissions.find_each do |submission|
        next if submission.plagiarism_checks.where('created_at > ?', 7.days.ago).exists?
        
        perform_later(submission.id, detection_provider)
      end
    end
  end
end