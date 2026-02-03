class AiGradingNotificationMailer < ApplicationMailer
  default from: Rails.application.credentials.dig(:email, :from_address) || 'noreply@uni-hub.edu'
  
  def review_required(instructor, ai_grading_result)
    @instructor = instructor
    @result = ai_grading_result
    @submission = @result.submission
    @assignment = @submission.assignment
    @course = @assignment.course
    @student = @submission.user
    @confidence_score = (@result.confidence_score * 100).round
    
    mail(
      to: @instructor.email,
      subject: "AI Grading Review Required - #{@student.name} (#{@course.name})"
    )
  end
  
  def grade_posted(student, submission)
    @student = student
    @submission = submission
    @assignment = submission.assignment
    @course = @assignment.course
    @grade = submission.grade
    
    mail(
      to: @student.email,
      subject: "Grade Posted - #{@assignment.title}"
    )
  end
  
  def batch_grading_complete(instructor, assignment, results_summary)
    @instructor = instructor
    @assignment = assignment
    @course = @assignment.course
    @total_graded = results_summary[:total_graded]
    @high_confidence = results_summary[:high_confidence]
    @needs_review = results_summary[:needs_review]
    @average_confidence = results_summary[:average_confidence]
    
    mail(
      to: @instructor.email,
      subject: "Batch AI Grading Complete - #{@assignment.title}"
    )
  end
end