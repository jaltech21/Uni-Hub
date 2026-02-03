class Instructors::PlagiarismController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_instructor_access
  before_action :set_department
  before_action :set_assignment, only: [:show, :check_assignment, :bulk_check]
  before_action :set_plagiarism_check, only: [:review, :approve, :flag_for_investigation, :dismiss]
  
  def dashboard
    @assignments = @department.assignments.includes(:plagiarism_checks)
    
    # Statistics
    @total_submissions = @course.submissions.count
    @checked_submissions = PlagiarismCheck.joins(submission: { assignment: :course })
                                         .where(courses: { id: @course.id })
                                         .where(processing_status: 'completed')
                                         .count
    
    @flagged_submissions = PlagiarismCheck.joins(submission: { assignment: :course })
                                         .where(courses: { id: @course.id })
                                         .where(requires_review: true)
                                         .count
    
    @high_similarity_cases = PlagiarismCheck.joins(submission: { assignment: :course })
                                           .where(courses: { id: @course.id })
                                           .where('similarity_percentage > 50')
                                           .count
    
    # Recent flagged cases
    @recent_cases = PlagiarismCheck.joins(submission: { assignment: :course })
                                  .where(courses: { id: @course.id })
                                  .where(requires_review: true)
                                  .order(created_at: :desc)
                                  .limit(10)
                                  .includes(:submission)
    
    # Similarity distribution
    @similarity_distribution = calculate_similarity_distribution
    
    # AI detection statistics
    @ai_detection_stats = calculate_ai_detection_stats
  end
  
  def show
    @submissions = @assignment.submissions.includes(:plagiarism_checks, :user)
    @checked_submissions = @submissions.joins(:plagiarism_checks)
                                     .where(plagiarism_checks: { processing_status: 'completed' })
    
    @pending_checks = @submissions.left_joins(:plagiarism_checks)
                                 .where(plagiarism_checks: { id: nil })
                                 .or(@submissions.joins(:plagiarism_checks)
                                               .where(plagiarism_checks: { processing_status: 'pending' }))
    
    @flagged_submissions = @submissions.joins(:plagiarism_checks)
                                     .where(plagiarism_checks: { requires_review: true })
    
    @high_similarity = @submissions.joins(:plagiarism_checks)
                                 .where('plagiarism_checks.similarity_percentage > 30')
                                 .order('plagiarism_checks.similarity_percentage DESC')
    
    # Assignment-specific statistics
    @assignment_stats = calculate_assignment_stats
  end
  
  def check_assignment
    detection_provider = params[:detection_provider] || 'internal'
    check_external = params[:check_external_sources] == '1'
    
    # Get submissions that haven't been checked recently
    submissions_to_check = @assignment.submissions
                                     .left_joins(:plagiarism_checks)
                                     .where(plagiarism_checks: { id: nil })
                                     .or(@assignment.submissions
                                                   .joins(:plagiarism_checks)
                                                   .where('plagiarism_checks.created_at < ?', 7.days.ago))
    
    if submissions_to_check.empty?
      redirect_to instructors_course_assignment_plagiarism_path(@course, @assignment),
                  notice: 'All submissions have been checked recently.'
      return
    end
    
    # Queue plagiarism check jobs
    check_jobs = []
    submissions_to_check.find_each do |submission|
      job = PlagiarismCheckJob.perform_later(submission.id, detection_provider)
      check_jobs << job
    end
    
    # Store job information for progress tracking
    session[:plagiarism_check_jobs] = {
      job_ids: check_jobs.map(&:job_id),
      total_count: submissions_to_check.count,
      started_at: Time.current
    }
    
    redirect_to instructors_course_assignment_plagiarism_path(@course, @assignment),
                notice: "Plagiarism checking started for #{submissions_to_check.count} submissions."
  end
  
  def check_progress
    job_info = session[:plagiarism_check_jobs]
    
    if job_info.blank?
      render json: { status: 'no_jobs', progress: 100 }
      return
    end
    
    # Count completed checks since job started
    completed_count = PlagiarismCheck.where('created_at >= ?', job_info['started_at']).count
    total_count = job_info['total_count']
    
    progress = total_count > 0 ? (completed_count.to_f / total_count * 100).round : 100
    
    render json: {
      status: progress >= 100 ? 'completed' : 'processing',
      progress: progress,
      completed: completed_count,
      total: total_count,
      flagged: PlagiarismCheck.where('created_at >= ? AND requires_review = true', job_info['started_at']).count
    }
  end
  
  def bulk_check
    assignment_ids = params[:assignment_ids] || []
    detection_provider = params[:detection_provider] || 'internal'
    
    assignments = @course.assignments.where(id: assignment_ids)
    total_submissions = 0
    
    assignments.each do |assignment|
      submissions_count = assignment.submissions
                                   .left_joins(:plagiarism_checks)
                                   .where(plagiarism_checks: { id: nil })
                                   .count
      
      total_submissions += submissions_count
      PlagiarismCheckJob.batch_check_assignment(assignment.id, detection_provider)
    end
    
    redirect_to instructors_course_plagiarism_dashboard_path(@course),
                notice: "Plagiarism checking queued for #{total_submissions} submissions across #{assignments.count} assignments."
  end
  
  def review
    @flagged_sections = parse_flagged_sections(@plagiarism_check.flagged_sections_data)
    @sources_found = parse_sources_found(@plagiarism_check.sources_found_data)
    @ai_detection = parse_ai_detection(@plagiarism_check.ai_detection_results_data)
    
    # Get similar cases for context
    @similar_cases = find_similar_cases(@plagiarism_check)
    
    # Student's submission history
    @student_history = get_student_plagiarism_history(@plagiarism_check.submission.user)
    
    # Generate recommended actions
    @recommended_actions = generate_recommended_actions(@plagiarism_check)
  end
  
  def approve
    @plagiarism_check.update!(
      review_status: 'approved',
      reviewed_by: current_user,
      reviewed_at: Time.current,
      instructor_notes: params[:instructor_notes]
    )
    
    # Send notification to student if configured
    if params[:notify_student] == '1'
      PlagiarismNotificationMailer.case_resolved(
        @plagiarism_check.submission.user,
        @plagiarism_check,
        'approved'
      ).deliver_later
    end
    
    redirect_to instructors_course_plagiarism_dashboard_path(@course),
                notice: 'Plagiarism case approved as acceptable similarity.'
  end
  
  def flag_for_investigation
    @plagiarism_check.update!(
      review_status: 'flagged_for_investigation',
      reviewed_by: current_user,
      reviewed_at: Time.current,
      instructor_notes: params[:instructor_notes],
      escalation_level: params[:escalation_level] || 'department'
    )
    
    # Notify academic integrity office
    notify_academic_integrity_office(@plagiarism_check)
    
    # Send notification to student
    PlagiarismNotificationMailer.investigation_notice(
      @plagiarism_check.submission.user,
      @plagiarism_check
    ).deliver_later
    
    redirect_to instructors_course_plagiarism_dashboard_path(@course),
                notice: 'Case flagged for academic integrity investigation.'
  end
  
  def dismiss
    @plagiarism_check.update!(
      review_status: 'dismissed',
      reviewed_by: current_user,
      reviewed_at: Time.current,
      instructor_notes: params[:instructor_notes]
    )
    
    redirect_to instructors_course_plagiarism_dashboard_path(@course),
                notice: 'Plagiarism alert dismissed.'
  end
  
  def export_report
    @checks = @course.plagiarism_checks
                    .joins(submission: :assignment)
                    .includes(:submission)
                    .where(processing_status: 'completed')
    
    # Filter by date range if provided
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      @checks = @checks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    
    # Filter by similarity threshold
    if params[:min_similarity].present?
      @checks = @checks.where('similarity_percentage >= ?', params[:min_similarity])
    end
    
    respond_to do |format|
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"plagiarism_report_#{@course.name.parameterize}_#{Date.current}.csv\""
        headers['Content-Type'] = 'text/csv'
      end
      
      format.json do
        render json: {
          course: @course.name,
          report_date: Date.current,
          total_cases: @checks.count,
          cases: @checks.map { |check| format_check_for_export(check) }
        }
      end
    end
  end
  
  def similarity_trends
    # Generate similarity trends over time
    @trend_data = calculate_similarity_trends
    @ai_detection_trends = calculate_ai_detection_trends
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          similarity_trends: @trend_data,
          ai_detection_trends: @ai_detection_trends
        }
      end
    end
  end
  
  def student_report
    student = User.find(params[:student_id])
    
    unless @course.students.include?(student)
      redirect_to instructors_course_plagiarism_dashboard_path(@course),
                  alert: 'Student not found in this course.'
      return
    end
    
    @student = student
    @plagiarism_history = get_detailed_student_history(@student)
    @assignments_completed = @course.assignments.joins(:submissions)
                                   .where(submissions: { user: @student })
                                   .count
    
    @similarity_pattern = analyze_student_similarity_pattern(@student)
  end
  
  private
  
  def set_department
    @department = current_user.departments.find(params[:department_id])
  end
  
  def set_assignment
    @assignment = @department.assignments.find(params[:assignment_id])
  end
  
  def set_plagiarism_check
    @plagiarism_check = PlagiarismCheck.joins(submission: { assignment: :course })
                                      .where(courses: { id: @course.id })
                                      .find(params[:id])
  end
  
  def ensure_instructor_access
    unless current_user.instructor? || current_user.admin?
      redirect_to root_path, alert: 'Access denied. Instructors only.'
    end
  end
  
  def calculate_similarity_distribution
    checks = PlagiarismCheck.joins(submission: { assignment: :course })
                           .where(courses: { id: @course.id })
                           .where(processing_status: 'completed')
    
    return {} if checks.empty?
    
    {
      '0-10%' => checks.where('similarity_percentage <= 10').count,
      '11-20%' => checks.where('similarity_percentage > 10 AND similarity_percentage <= 20').count,
      '21-30%' => checks.where('similarity_percentage > 20 AND similarity_percentage <= 30').count,
      '31-50%' => checks.where('similarity_percentage > 30 AND similarity_percentage <= 50').count,
      '51-70%' => checks.where('similarity_percentage > 50 AND similarity_percentage <= 70').count,
      '70%+' => checks.where('similarity_percentage > 70').count
    }
  end
  
  def calculate_ai_detection_stats
    checks_with_ai_data = PlagiarismCheck.joins(submission: { assignment: :course })
                                        .where(courses: { id: @course.id })
                                        .where.not(ai_detection_results: [nil, ''])
    
    return {} if checks_with_ai_data.empty?
    
    total_checks = checks_with_ai_data.count
    high_ai_probability = 0
    medium_ai_probability = 0
    low_ai_probability = 0
    
    checks_with_ai_data.each do |check|
      ai_data = parse_ai_detection(check.ai_detection_results_data)
      probability = ai_data[:probability] || 0
      
      if probability >= 0.7
        high_ai_probability += 1
      elsif probability >= 0.4
        medium_ai_probability += 1
      else
        low_ai_probability += 1
      end
    end
    
    {
      total_with_ai_analysis: total_checks,
      high_probability: high_ai_probability,
      medium_probability: medium_ai_probability,
      low_probability: low_ai_probability,
      high_probability_percentage: (high_ai_probability.to_f / total_checks * 100).round(1)
    }
  end
  
  def calculate_assignment_stats
    checks = @assignment.plagiarism_checks.where(processing_status: 'completed')
    
    return {} if checks.empty?
    
    similarities = checks.pluck(:similarity_percentage)
    
    {
      total_checked: checks.count,
      average_similarity: similarities.sum.to_f / similarities.length,
      median_similarity: calculate_median(similarities),
      max_similarity: similarities.max,
      flagged_count: checks.where(requires_review: true).count,
      high_similarity_count: checks.where('similarity_percentage > 50').count
    }
  end
  
  def calculate_median(array)
    sorted = array.sort
    length = sorted.length
    length.even? ? (sorted[length/2 - 1] + sorted[length/2]) / 2.0 : sorted[length/2]
  end
  
  def parse_flagged_sections(flagged_sections_json)
    return [] if flagged_sections_json.blank?
    
    begin
      JSON.parse(flagged_sections_json)
    rescue JSON::ParserError
      []
    end
  end
  
  def parse_sources_found(sources_json)
    return [] if sources_json.blank?
    
    begin
      JSON.parse(sources_json)
    rescue JSON::ParserError
      []
    end
  end
  
  def parse_ai_detection(ai_detection_json)
    return {} if ai_detection_json.blank?
    
    begin
      JSON.parse(ai_detection_json)
    rescue JSON::ParserError
      {}
    end
  end
  
  def find_similar_cases(plagiarism_check)
    # Find other cases with similar similarity percentages or sources
    similarity_range = 5 # +/- 5%
    
    PlagiarismCheck.joins(submission: { assignment: :course })
                  .where(courses: { id: @course.id })
                  .where.not(id: plagiarism_check.id)
                  .where(
                    'similarity_percentage BETWEEN ? AND ?',
                    plagiarism_check.similarity_percentage - similarity_range,
                    plagiarism_check.similarity_percentage + similarity_range
                  )
                  .limit(5)
                  .includes(:submission)
  end
  
  def get_student_plagiarism_history(student)
    PlagiarismCheck.joins(submission: { assignment: :course })
                  .where(courses: { id: @course.id })
                  .where(submissions: { user: student })
                  .order(created_at: :desc)
                  .limit(10)
  end
  
  def get_detailed_student_history(student)
    checks = PlagiarismCheck.joins(submission: { assignment: :course })
                           .where(courses: { id: @course.id })
                           .where(submissions: { user: student })
                           .includes(:submission)
                           .order(created_at: :desc)
    
    {
      total_submissions_checked: checks.count,
      average_similarity: checks.average(:similarity_percentage)&.round(2),
      highest_similarity: checks.maximum(:similarity_percentage),
      flagged_cases: checks.where(requires_review: true).count,
      recent_checks: checks.limit(5),
      similarity_trend: calculate_student_similarity_trend(checks)
    }
  end
  
  def calculate_student_similarity_trend(checks)
    # Calculate if student's similarity scores are trending up or down
    recent_checks = checks.limit(5).pluck(:similarity_percentage, :created_at)
    return 'insufficient_data' if recent_checks.length < 3
    
    # Simple linear trend calculation
    x_values = (0...recent_checks.length).to_a
    y_values = recent_checks.map(&:first)
    
    n = recent_checks.length
    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_xy = x_values.zip(y_values).map { |x, y| x * y }.sum
    sum_x_squared = x_values.map { |x| x * x }.sum
    
    slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x_squared - sum_x * sum_x)
    
    if slope > 2
      'increasing'
    elsif slope < -2
      'decreasing'
    else
      'stable'
    end
  end
  
  def analyze_student_similarity_pattern(student)
    checks = PlagiarismCheck.joins(submission: { assignment: :course })
                           .where(courses: { id: @course.id })
                           .where(submissions: { user: student })
                           .order(:created_at)
    
    return {} if checks.count < 2
    
    similarities = checks.pluck(:similarity_percentage)
    
    {
      consistency: calculate_consistency(similarities),
      peak_similarity: similarities.max,
      average_similarity: similarities.sum.to_f / similarities.length,
      pattern_type: determine_pattern_type(similarities)
    }
  end
  
  def calculate_consistency(similarities)
    return 'consistent' if similarities.length < 3
    
    variance = calculate_variance(similarities)
    
    if variance < 50
      'consistent'
    elsif variance < 200
      'moderate_variation'
    else
      'highly_variable'
    end
  end
  
  def calculate_variance(values)
    mean = values.sum.to_f / values.length
    sum_of_squares = values.map { |v| (v - mean) ** 2 }.sum
    sum_of_squares / values.length
  end
  
  def determine_pattern_type(similarities)
    return 'insufficient_data' if similarities.length < 3
    
    first_half = similarities.first(similarities.length / 2)
    second_half = similarities.last(similarities.length / 2)
    
    first_avg = first_half.sum.to_f / first_half.length
    second_avg = second_half.sum.to_f / second_half.length
    
    if second_avg > first_avg + 10
      'increasing_concern'
    elsif first_avg > second_avg + 10
      'improving'
    else
      'stable'
    end
  end
  
  def generate_recommended_actions(plagiarism_check)
    actions = []
    similarity = plagiarism_check.similarity_percentage
    
    if similarity > 70
      actions << { 
        type: 'high_priority', 
        action: 'Immediate investigation required',
        description: 'Very high similarity detected. Contact academic integrity office.'
      }
    elsif similarity > 50
      actions << { 
        type: 'medium_priority',
        action: 'Schedule meeting with student',
        description: 'Discuss proper citation and academic integrity policies.'
      }
    elsif similarity > 30
      actions << { 
        type: 'low_priority',
        action: 'Provide feedback on citation',
        description: 'Guide student on proper attribution and paraphrasing.'
      }
    end
    
    # AI detection recommendations
    ai_data = parse_ai_detection(plagiarism_check.ai_detection_results_data)
    if ai_data[:probability] && ai_data[:probability] > 0.7
      actions << {
        type: 'ai_concern',
        action: 'Investigate AI usage',
        description: 'High probability of AI-generated content detected.'
      }
    end
    
    # Pattern-based recommendations
    student_history = get_student_plagiarism_history(plagiarism_check.submission.user)
    if student_history.count > 1 && student_history.any? { |check| check.similarity_percentage > 30 }
      actions << {
        type: 'pattern_concern',
        action: 'Review student\'s academic integrity training',
        description: 'Multiple instances of similarity detected for this student.'
      }
    end
    
    actions
  end
  
  def notify_academic_integrity_office(plagiarism_check)
    integrity_coordinators = User.where(role: 'academic_integrity_coordinator')
    
    integrity_coordinators.each do |coordinator|
      PlagiarismAlertMailer.investigation_flagged(
        coordinator,
        plagiarism_check
      ).deliver_later
    end
  end
  
  def format_check_for_export(check)
    {
      student_name: check.submission.user.name,
      student_email: check.submission.user.email,
      assignment: check.submission.assignment.title,
      submission_date: check.submission.created_at,
      similarity_percentage: check.similarity_percentage,
      requires_review: check.requires_review,
      review_status: check.review_status,
      flagged_sections_count: parse_flagged_sections(check.flagged_sections_data).length,
      sources_found_count: parse_sources_found(check.sources_found_data).length,
      ai_probability: parse_ai_detection(check.ai_detection_results_data)[:probability],
      processed_at: check.processed_at
    }
  end
  
  def calculate_similarity_trends
    # Calculate trends over the last 6 months
    6.downto(0).map do |months_ago|
      start_date = months_ago.months.ago.beginning_of_month
      end_date = months_ago.months.ago.end_of_month
      
      checks = PlagiarismCheck.joins(submission: { assignment: :course })
                             .where(courses: { id: @course.id })
                             .where(created_at: start_date..end_date)
                             .where(processing_status: 'completed')
      
      {
        month: start_date.strftime('%B %Y'),
        total_checks: checks.count,
        average_similarity: checks.average(:similarity_percentage)&.round(2) || 0,
        flagged_cases: checks.where(requires_review: true).count,
        high_similarity_cases: checks.where('similarity_percentage > 50').count
      }
    end
  end
  
  def calculate_ai_detection_trends
    6.downto(0).map do |months_ago|
      start_date = months_ago.months.ago.beginning_of_month
      end_date = months_ago.months.ago.end_of_month
      
      checks = PlagiarismCheck.joins(submission: { assignment: :course })
                             .where(courses: { id: @course.id })
                             .where(created_at: start_date..end_date)
                             .where.not(ai_detection_results: [nil, ''])
      
      high_probability_count = 0
      checks.each do |check|
        ai_data = parse_ai_detection(check.ai_detection_results_data)
        high_probability_count += 1 if ai_data[:probability] && ai_data[:probability] > 0.7
      end
      
      {
        month: start_date.strftime('%B %Y'),
        total_ai_checks: checks.count,
        high_probability_cases: high_probability_count,
        ai_detection_rate: checks.count > 0 ? (high_probability_count.to_f / checks.count * 100).round(1) : 0
      }
    end
  end
end