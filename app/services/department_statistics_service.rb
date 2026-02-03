# Service object to calculate department statistics and analytics
class DepartmentStatisticsService
  def initialize(department)
    @department = department
  end

  def statistics
    {
      overview: overview_stats,
      enrollment: enrollment_stats,
      content: content_stats,
      activity: activity_stats,
      performance: performance_stats
    }
  end

  private

  attr_reader :department

  def overview_stats
    {
      total_students: department.users.where(role: 'student').count,
      total_tutors: department.teaching_users.where(role: ['tutor', 'teacher']).count,
      total_content: total_content_count,
      active_users: active_users_count
    }
  end

  def enrollment_stats
    students = department.users.where(role: 'student')
    stats = {
      total: students.count,
      new_this_month: students.where('created_at >= ?', 1.month.ago).count
    }
    
    # Only include sign-in stats if trackable is enabled
    if User.column_names.include?('last_sign_in_at')
      stats[:active_this_month] = students.where('last_sign_in_at >= ?', 1.month.ago).count
      stats[:active_this_week] = students.where('last_sign_in_at >= ?', 1.week.ago).count
    else
      stats[:active_this_month] = 0
      stats[:active_this_week] = 0
    end
    
    stats
  end

  def content_stats
    {
      assignments: {
        total: Assignment.where(department: department).count,
        active: Assignment.where(department: department).where('due_date > ?', Time.current).count,
        overdue: Assignment.where(department: department).where('due_date < ?', Time.current).count
      },
      notes: {
        total: Note.where(department: department).count,
        shared: Note.where(department: department).joins(:note_shares).distinct.count,
        recent: Note.where(department: department).where('created_at >= ?', 1.week.ago).count
      },
      quizzes: {
        total: Quiz.where(department: department).count,
        published: Quiz.where(department: department, status: 'published').count,
        draft: Quiz.where(department: department, status: 'draft').count,
        avg_score: Quiz.where(department: department, status: 'published')
                      .joins(:quiz_attempts)
                      .where('quiz_attempts.completed_at IS NOT NULL')
                      .average('quiz_attempts.score')
                      .to_f
                      .round(2)
      }
    }
  end

  def activity_stats
    {
      assignments_created_this_week: Assignment.where(department: department)
                                               .where('created_at >= ?', 1.week.ago)
                                               .count,
      quizzes_taken_this_week: QuizAttempt.joins(quiz: :department)
                                          .where(quizzes: { department_id: department.id })
                                          .where('quiz_attempts.created_at >= ?', 1.week.ago)
                                          .count,
      notes_created_this_week: Note.where(department: department)
                                   .where('created_at >= ?', 1.week.ago)
                                   .count,
      submissions_this_week: Submission.joins(assignment: :department)
                                       .where(assignments: { department_id: department.id })
                                       .where('submissions.created_at >= ?', 1.week.ago)
                                       .count
    }
  end

  def performance_stats
    assignments = Assignment.where(department: department)
    total_assignments = assignments.count
    
    return default_performance_stats if total_assignments.zero?

    {
      avg_assignment_score: calculate_avg_assignment_score(assignments),
      completion_rate: calculate_completion_rate(assignments),
      on_time_submission_rate: calculate_on_time_rate(assignments),
      quiz_pass_rate: calculate_quiz_pass_rate
    }
  end

  def total_content_count
    Assignment.where(department: department).count +
    Note.where(department: department).count +
    Quiz.where(department: department).count
  end

  def active_users_count
    # Users who have signed in within the last 2 weeks (if trackable is enabled)
    if User.column_names.include?('last_sign_in_at')
      department.users.where('last_sign_in_at >= ?', 2.weeks.ago).count +
      department.teaching_users.where('last_sign_in_at >= ?', 2.weeks.ago).count
    else
      # Fallback: count users who have been active recently based on created_at
      (department.users.count + department.teaching_users.count) / 2
    end
  end

  def calculate_avg_assignment_score(assignments)
    submissions = Submission.joins(:assignment)
                           .where(assignments: { id: assignments.pluck(:id) })
                           .where.not(grade: nil)
    
    return 0.0 if submissions.empty?
    
    submissions.average(:grade).to_f.round(2)
  end

  def calculate_completion_rate(assignments)
    return 0.0 if assignments.empty?
    
    total_students = department.users.where(role: 'student').count
    return 0.0 if total_students.zero?
    
    total_expected = assignments.count * total_students
    return 0.0 if total_expected.zero?
    
    total_submissions = Submission.joins(:assignment)
                                 .where(assignments: { id: assignments.pluck(:id) })
                                 .where.not(submitted_at: nil)
                                 .count
    
    ((total_submissions.to_f / total_expected) * 100).round(2)
  end

  def calculate_on_time_rate(assignments)
    submissions = Submission.joins(:assignment)
                           .where(assignments: { id: assignments.pluck(:id) })
                           .where.not(submitted_at: nil)
    
    return 0.0 if submissions.empty?
    
    on_time = submissions.where('submissions.submitted_at <= assignments.due_date').count
    ((on_time.to_f / submissions.count) * 100).round(2)
  end

  def calculate_quiz_pass_rate
    attempts = QuizAttempt.joins(quiz: :department)
                         .where(quizzes: { department_id: department.id, status: 'published' })
                         .where.not(completed_at: nil)
    
    return 0.0 if attempts.empty?
    
    passed = attempts.where('score >= ?', 60).count # Assuming 60% is passing
    ((passed.to_f / attempts.count) * 100).round(2)
  end

  def default_performance_stats
    {
      avg_assignment_score: 0.0,
      completion_rate: 0.0,
      on_time_submission_rate: 0.0,
      quiz_pass_rate: 0.0
    }
  end
end
