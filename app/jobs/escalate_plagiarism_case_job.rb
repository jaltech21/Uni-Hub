class EscalatePlagiarismCaseJob < ApplicationJob
  queue_as :integrity
  
  def perform(plagiarism_check_id)
    plagiarism_check = PlagiarismCheck.find(plagiarism_check_id)
    
    # Only escalate if still pending review
    return unless plagiarism_check.requires_review?
    return if plagiarism_check.review_status != 'pending'
    
    # Mark as escalated
    plagiarism_check.update!(
      escalation_level: 'department',
      escalated_at: Time.current
    )
    
    # Notify department head or academic integrity office
    notify_escalation_contacts(plagiarism_check)
    
    # Create high-priority notification for instructor
    create_escalation_notification(plagiarism_check)
  end
  
  private
  
  def notify_escalation_contacts(check)
    course = check.submission.assignment.course
    
    # Notify department head
    if course.department&.head
      PlagiarismAlertMailer.case_escalated(
        course.department.head,
        check
      ).deliver_now
    end
    
    # Notify academic integrity coordinators
    integrity_coordinators = User.where(role: 'academic_integrity_coordinator')
    integrity_coordinators.each do |coordinator|
      PlagiarismAlertMailer.case_escalated(
        coordinator,
        check
      ).deliver_now
    end
  end
  
  def create_escalation_notification(check)
    instructor = check.submission.assignment.course.instructor
    
    Notification.create!(
      user: instructor,
      title: 'Plagiarism Case Escalated',
      message: "Unreviewed plagiarism case for #{check.submission.user.name} has been escalated to department level.",
      notification_type: 'escalation_alert',
      related_object: check,
      priority: 'high'
    )
  end
end