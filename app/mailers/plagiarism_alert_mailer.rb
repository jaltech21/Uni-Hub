class PlagiarismAlertMailer < ApplicationMailer
  default from: Rails.application.credentials.dig(:email, :from_address) || 'noreply@uni-hub.edu'
  
  def instructor_alert(instructor, plagiarism_check)
    @instructor = instructor
    @check = plagiarism_check
    @submission = @check.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @student = @submission.user
    @similarity = @check.similarity_percentage
    
    mail(
      to: @instructor.email,
      subject: "Plagiarism Alert - #{@student.name} (#{@similarity}% similarity)"
    )
  end
  
  def integrity_office_alert(coordinator, plagiarism_check)
    @coordinator = coordinator
    @check = plagiarism_check
    @submission = @check.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @student = @submission.user
    @instructor = @course.instructor
    @similarity = @check.similarity_percentage
    
    mail(
      to: @coordinator.email,
      subject: "High Similarity Case - Investigation Required (#{@similarity}%)"
    )
  end
  
  def student_notification(student, plagiarism_check)
    @student = student
    @check = plagiarism_check
    @submission = @check.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @instructor = @course.instructor
    
    mail(
      to: @student.email,
      subject: "Submission Under Review - #{@assignment.title}"
    )
  end
  
  def investigation_notice(student, plagiarism_check)
    @student = student
    @check = plagiarism_check
    @submission = @check.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @instructor = @course.instructor
    @similarity = @check.similarity_percentage
    
    mail(
      to: @student.email,
      subject: "Academic Integrity Investigation - #{@assignment.title}"
    )
  end
  
  def investigation_flagged(coordinator, plagiarism_check)
    @coordinator = coordinator
    @check = plagiarism_check
    @submission = @check.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @student = @submission.user
    @instructor = @course.instructor
    @similarity = @check.similarity_percentage
    
    mail(
      to: @coordinator.email,
      subject: "Case Flagged for Investigation - #{@student.name}"
    )
  end
  
  def case_resolved(student, plagiarism_check, resolution)
    @student = student
    @check = plagiarism_check
    @submission = @check.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @resolution = resolution
    
    mail(
      to: @student.email,
      subject: "Plagiarism Case Resolved - #{@assignment.title}"
    )
  end
end