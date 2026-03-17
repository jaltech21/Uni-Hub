class Instructors::AiGradingController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_instructor_access
  before_action :set_department
  before_action :set_assignment, only: [:show, :grade_assignment, :review_results, :approve_grade, :reject_grade]
  before_action :set_grading_result, only: [:review_results, :approve_grade, :reject_grade]
  
  def dashboard
    @assignments = @department.assignments.includes(:grading_rubrics, :ai_grading_results)
    @ai_enabled_assignments = @assignments.joins(:grading_rubrics).where(grading_rubrics: { ai_grading_enabled: true })
    
    # Statistics
    @total_submissions = @course.submissions.count
    @ai_graded_submissions = AiGradingResult.joins(submission: { assignment: :department })
                                           .where(departments: { id: @department.id })
                                           .where(processing_status: 'completed')
                                           .count
    
    @pending_reviews = AiGradingResult.joins(submission: { assignment: :course })
                                     .where(courses: { id: @course.id })
                                     .where(requires_review: true)
                                     .where(review_status: 'pending')
                                     .count
    
    @accuracy_stats = calculate_accuracy_stats
    
    # Recent activity
    @recent_results = AiGradingResult.joins(submission: { assignment: :course })
                                    .where(courses: { id: @course.id })
                                    .order(created_at: :desc)
                                    .limit(10)
                                    .includes(:submission, :grading_rubric)
  end
  
  def show
    @rubrics = @assignment.grading_rubrics.includes(:ai_grading_results)
    @ai_enabled_rubrics = @rubrics.where(ai_grading_enabled: true)
    
    @submissions = @assignment.submissions.includes(:ai_grading_results, :user)
    @graded_submissions = @submissions.joins(:ai_grading_results)
                                    .where(ai_grading_results: { processing_status: 'completed' })
    
    @pending_submissions = @submissions.left_joins(:ai_grading_results)
                                     .where(ai_grading_results: { id: nil })
    
    @review_required = @submissions.joins(:ai_grading_results)
                                 .where(ai_grading_results: { requires_review: true, review_status: 'pending' })
    
    # Grade distribution
    @grade_distribution = calculate_grade_distribution
    
    # Confidence score distribution
    @confidence_distribution = calculate_confidence_distribution
  end
  
  def grade_assignment
    rubric = @assignment.grading_rubrics.ai_enabled.find(params[:rubric_id])
    ai_provider = params[:ai_provider] || 'openai'
    
    # Get submissions that haven't been AI graded with this rubric
    submissions_to_grade = @assignment.submissions
                                     .left_joins(:ai_grading_results)
                                     .where(ai_grading_results: { id: nil })
                                     .or(@assignment.submissions
                                                   .joins(:ai_grading_results)
                                                   .where.not(ai_grading_results: { grading_rubric_id: rubric.id }))
    
    if submissions_to_grade.empty?
      redirect_to instructors_course_assignment_ai_grading_path(@course, @assignment),
                  notice: 'All submissions have already been graded with this rubric.'
      return
    end
    
    # Queue grading jobs
    grading_jobs = []
    submissions_to_grade.find_each do |submission|
      job = AiGradingJob.perform_later(submission.id, rubric.id, ai_provider)
      grading_jobs << job
    end
    
    # Store job IDs in session for progress tracking
    session[:grading_jobs] = grading_jobs.map(&:job_id)
    
    redirect_to instructors_course_assignment_ai_grading_path(@course, @assignment),
                notice: "AI grading started for #{submissions_to_grade.count} submissions. Results will appear as they're processed."
  end
  
  def grading_progress
    job_ids = session[:grading_jobs] || []
    
    if job_ids.empty?
      render json: { status: 'no_jobs', progress: 100 }
      return
    end
    
    # Check job statuses (this is a simplified version - in production you'd use a proper job tracking system)
    completed_count = AiGradingResult.where(created_at: 5.minutes.ago..Time.current).count
    total_count = job_ids.length
    
    progress = total_count > 0 ? (completed_count.to_f / total_count * 100).round : 100
    
    render json: {
      status: progress >= 100 ? 'completed' : 'processing',
      progress: progress,
      completed: completed_count,
      total: total_count
    }
  end
  
  def review_results
    @feedback_data = parse_ai_feedback(@grading_result.ai_feedback_data)
    @rubric_criteria = @grading_result.grading_rubric.criteria_list
    
    # Get other AI results for this assignment for comparison
    @similar_results = AiGradingResult.joins(:submission)
                                     .where(submissions: { assignment_id: @assignment.id })
                                     .where.not(id: @grading_result.id)
                                     .where(processing_status: 'completed')
                                     .order(ai_score: :desc)
                                     .limit(5)
    
    # Calculate statistics for context
    @assignment_stats = {
      average_score: @assignment.ai_grading_results.where(processing_status: 'completed').average(:ai_score)&.round(2),
      median_score: calculate_median_score,
      score_range: calculate_score_range
    }
  end
  
  def approve_grade
    @grading_result.update!(
      review_status: 'approved',
      reviewed_by: current_user,
      reviewed_at: Time.current,
      instructor_notes: params[:instructor_notes]
    )
    
    # Update submission grade if requested
    if params[:update_submission_grade] == '1'
      @grading_result.submission.update!(
        grade: @grading_result.ai_score,
        graded_at: Time.current,
        grader_notes: "AI-graded and approved by #{current_user.name}"
      )
    end
    
    # Send notification to student if grade was posted
    if params[:notify_student] == '1'
      GradeNotificationMailer.grade_posted(
        @grading_result.submission.user,
        @grading_result.submission
      ).deliver_later
    end
    
    redirect_to instructors_course_assignment_ai_grading_path(@course, @assignment),
                notice: 'AI grade approved successfully.'
  end
  
  def reject_grade
    @grading_result.update!(
      review_status: 'rejected',
      reviewed_by: current_user,
      reviewed_at: Time.current,
      instructor_notes: params[:instructor_notes]
    )
    
    # Optionally schedule regrade with different AI provider or settings
    if params[:schedule_regrade] == '1'
      different_provider = @grading_result.ai_provider == 'openai' ? 'anthropic' : 'openai'
      AiGradingJob.perform_later(
        @grading_result.submission.id,
        @grading_result.grading_rubric.id,
        different_provider
      )
    end
    
    redirect_to instructors_course_assignment_ai_grading_path(@course, @assignment),
                notice: 'AI grade rejected. Consider manual grading for this submission.'
  end
  
  def batch_review
    result_ids = params[:result_ids] || []
    action_type = params[:action_type] # 'approve_all', 'reject_all', 'approve_high_confidence'
    
    results = AiGradingResult.where(id: result_ids)
    
    case action_type
    when 'approve_all'
      approve_batch_results(results)
    when 'reject_all'
      reject_batch_results(results)
    when 'approve_high_confidence'
      approve_high_confidence_results(results)
    end
    
    redirect_to instructors_course_assignment_ai_grading_path(@course, @assignment),
                notice: "Batch action completed for #{results.count} results."
  end
  
  def export_results
    @results = @assignment.ai_grading_results.includes(:submission, :grading_rubric)
    
    respond_to do |format|
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"ai_grading_results_#{@assignment.title.parameterize}.csv\""
        headers['Content-Type'] = 'text/csv'
      end
      
      format.json do
        render json: {
          assignment: @assignment.title,
          results: @results.map { |result| format_result_for_export(result) }
        }
      end
    end
  end
  
  def accuracy_report
    @rubrics = @course.grading_rubrics.ai_enabled
    @selected_rubric = @rubrics.find(params[:rubric_id]) if params[:rubric_id].present?
    
    if @selected_rubric
      @accuracy_data = calculate_rubric_accuracy(@selected_rubric)
      @improvement_suggestions = generate_improvement_suggestions(@selected_rubric)
    end
    
    @overall_accuracy = calculate_overall_accuracy
  end
  
  private
  
  def set_department
    @department = current_user.departments.find(params[:department_id])
  end
  
  def set_assignment
    @assignment = @department.assignments.find(params[:assignment_id])
  end
  
  def set_grading_result
    @grading_result = @assignment.ai_grading_results.find(params[:id])
  end
  
  def ensure_instructor_access
    unless current_user.instructor? || current_user.admin?
      redirect_to root_path, alert: 'Access denied. Instructors only.'
    end
  end
  
  def calculate_accuracy_stats
    # Compare AI grades with instructor grades where both exist
    ai_results = AiGradingResult.joins(submission: { assignment: :course })
                               .where(courses: { id: @course.id })
                               .where(processing_status: 'completed')
                               .joins('INNER JOIN submissions ON submissions.id = ai_grading_results.submission_id')
                               .where.not(submissions: { grade: nil })
    
    return {} if ai_results.empty?
    
    total_comparisons = ai_results.count
    accurate_within_5_percent = 0
    accurate_within_10_percent = 0
    
    ai_results.each do |result|
      instructor_grade = result.submission.grade
      ai_grade = result.ai_score
      max_points = result.grading_rubric.total_points
      
      percentage_diff = ((instructor_grade - ai_grade).abs / max_points * 100)
      
      accurate_within_10_percent += 1 if percentage_diff <= 10
      accurate_within_5_percent += 1 if percentage_diff <= 5
    end
    
    {
      total_comparisons: total_comparisons,
      accuracy_5_percent: (accurate_within_5_percent.to_f / total_comparisons * 100).round(1),
      accuracy_10_percent: (accurate_within_10_percent.to_f / total_comparisons * 100).round(1)
    }
  end
  
  def calculate_grade_distribution
    scores = @assignment.ai_grading_results
                       .where(processing_status: 'completed')
                       .pluck(:ai_score)
    
    return {} if scores.empty?
    
    max_score = @assignment.grading_rubrics.maximum(:total_points) || 100
    
    {
      '90-100%' => scores.count { |s| s >= max_score * 0.9 },
      '80-89%' => scores.count { |s| s >= max_score * 0.8 && s < max_score * 0.9 },
      '70-79%' => scores.count { |s| s >= max_score * 0.7 && s < max_score * 0.8 },
      '60-69%' => scores.count { |s| s >= max_score * 0.6 && s < max_score * 0.7 },
      'Below 60%' => scores.count { |s| s < max_score * 0.6 }
    }
  end
  
  def calculate_confidence_distribution
    confidence_scores = @assignment.ai_grading_results
                                  .where(processing_status: 'completed')
                                  .pluck(:confidence_score)
    
    return {} if confidence_scores.empty?
    
    {
      'High (80-100%)' => confidence_scores.count { |c| c >= 0.8 },
      'Medium (60-79%)' => confidence_scores.count { |c| c >= 0.6 && c < 0.8 },
      'Low (40-59%)' => confidence_scores.count { |c| c >= 0.4 && c < 0.6 },
      'Very Low (<40%)' => confidence_scores.count { |c| c < 0.4 }
    }
  end
  
  def parse_ai_feedback(feedback_json)
    return {} if feedback_json.blank?
    
    begin
      JSON.parse(feedback_json)
    rescue JSON::ParserError
      { overall_feedback: feedback_json, format: 'text' }
    end
  end
  
  def calculate_median_score
    scores = @assignment.ai_grading_results
                       .where(processing_status: 'completed')
                       .pluck(:ai_score)
                       .sort
    
    return 0 if scores.empty?
    
    mid = scores.length / 2
    scores.length.odd? ? scores[mid] : (scores[mid - 1] + scores[mid]) / 2.0
  end
  
  def calculate_score_range
    scores = @assignment.ai_grading_results
                       .where(processing_status: 'completed')
                       .pluck(:ai_score)
    
    return { min: 0, max: 0 } if scores.empty?
    
    { min: scores.min, max: scores.max }
  end
  
  def approve_batch_results(results)
    results.update_all(
      review_status: 'approved',
      reviewed_by_id: current_user.id,
      reviewed_at: Time.current
    )
    
    # Update submission grades for high-confidence results
    high_confidence_results = results.where('confidence_score >= 0.8')
    high_confidence_results.each do |result|
      result.submission.update!(
        grade: result.ai_score,
        graded_at: Time.current,
        grader_notes: "AI-graded (batch approved)"
      )
    end
  end
  
  def reject_batch_results(results)
    results.update_all(
      review_status: 'rejected',
      reviewed_by_id: current_user.id,
      reviewed_at: Time.current
    )
  end
  
  def approve_high_confidence_results(results)
    high_confidence = results.where('confidence_score >= 0.8')
    approve_batch_results(high_confidence)
    
    low_confidence = results.where('confidence_score < 0.8')
    low_confidence.update_all(review_status: 'needs_manual_review')
  end
  
  def format_result_for_export(result)
    {
      student_name: result.submission.user.name,
      student_email: result.submission.user.email,
      ai_score: result.ai_score,
      confidence_score: result.confidence_score,
      review_status: result.review_status,
      processed_at: result.processed_at,
      rubric_name: result.grading_rubric.name,
      feedback: result.ai_feedback_data
    }
  end
  
  def calculate_rubric_accuracy(rubric)
    # Detailed accuracy analysis for a specific rubric
    results = rubric.ai_grading_results
                   .joins(:submission)
                   .where(processing_status: 'completed')
                   .where.not(submissions: { grade: nil })
    
    accuracy_data = {
      total_submissions: results.count,
      average_confidence: results.average(:confidence_score)&.round(3),
      accuracy_by_confidence: {},
      common_discrepancies: []
    }
    
    # Group by confidence ranges
    confidence_ranges = [
      { range: '0.8-1.0', min: 0.8, max: 1.0 },
      { range: '0.6-0.79', min: 0.6, max: 0.79 },
      { range: '0.4-0.59', min: 0.4, max: 0.59 },
      { range: '0.0-0.39', min: 0.0, max: 0.39 }
    ]
    
    confidence_ranges.each do |range_data|
      range_results = results.where(
        'confidence_score >= ? AND confidence_score <= ?',
        range_data[:min], range_data[:max]
      )
      
      next if range_results.empty?
      
      accurate_count = range_results.count do |result|
        instructor_grade = result.submission.grade
        ai_grade = result.ai_score
        percentage_diff = ((instructor_grade - ai_grade).abs / rubric.total_points * 100)
        percentage_diff <= 10
      end
      
      accuracy_data[:accuracy_by_confidence][range_data[:range]] = {
        count: range_results.count,
        accuracy_percentage: (accurate_count.to_f / range_results.count * 100).round(1)
      }
    end
    
    accuracy_data
  end
  
  def generate_improvement_suggestions(rubric)
    suggestions = []
    
    # Analyze common issues
    low_confidence_results = rubric.ai_grading_results.where('confidence_score < 0.6')
    
    if low_confidence_results.count > rubric.ai_grading_results.count * 0.3
      suggestions << "Consider refining rubric criteria - #{low_confidence_results.count} results had low confidence scores"
    end
    
    # Check for inconsistent grading
    score_variance = calculate_score_variance(rubric)
    if score_variance > 0.3
      suggestions << "High score variance detected - consider adding more specific scoring guidelines"
    end
    
    # Check rubric criteria clarity
    if rubric.criteria_list.any? { |c| c['description'].length < 50 }
      suggestions << "Some criteria have brief descriptions - more detailed explanations may improve AI accuracy"
    end
    
    suggestions
  end
  
  def calculate_score_variance(rubric)
    scores = rubric.ai_grading_results
                  .where(processing_status: 'completed')
                  .pluck(:ai_score)
    
    return 0 if scores.length < 2
    
    mean = scores.sum.to_f / scores.length
    variance = scores.sum { |score| (score - mean) ** 2 } / scores.length
    Math.sqrt(variance) / rubric.total_points
  end
  
  def calculate_overall_accuracy
    # Course-wide accuracy statistics
    ai_results = AiGradingResult.joins(submission: { assignment: :course })
                               .where(courses: { id: @course.id })
                               .where(processing_status: 'completed')
    
    total_results = ai_results.count
    return {} if total_results == 0
    
    high_confidence_results = ai_results.where('confidence_score >= 0.8').count
    reviewed_results = ai_results.where.not(review_status: 'pending').count
    approved_results = ai_results.where(review_status: 'approved').count
    
    {
      total_ai_grades: total_results,
      high_confidence_percentage: (high_confidence_results.to_f / total_results * 100).round(1),
      review_completion_rate: reviewed_results > 0 ? (reviewed_results.to_f / total_results * 100).round(1) : 0,
      approval_rate: reviewed_results > 0 ? (approved_results.to_f / reviewed_results * 100).round(1) : 0
    }
  end
end