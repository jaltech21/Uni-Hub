class AnalyticsDashboard < ApplicationRecord
  belongs_to :user
  belongs_to :department, optional: true
  has_many :dashboard_widgets, dependent: :destroy
  has_many :dashboard_reports, dependent: :destroy
  
  validates :title, presence: true, length: { maximum: 100 }
  validates :dashboard_type, presence: true, inclusion: { 
    in: %w[student teacher admin department institutional],
    message: "%{value} is not a valid dashboard type" 
  }
  
  scope :by_type, ->(type) { where(dashboard_type: type) if type.present? }
  scope :active, -> { where(active: true) }
  scope :by_user, ->(user) { where(user: user) }
  
  # Dashboard configuration stored as JSON
  serialize :layout_config, coder: JSON
  serialize :filter_config, coder: JSON
  serialize :permissions_config, coder: JSON
  
  # Default dashboard layouts
  def self.default_student_layout
    {
      widgets: [
        { type: 'grade_overview', position: { x: 0, y: 0, w: 6, h: 4 } },
        { type: 'assignment_progress', position: { x: 6, y: 0, w: 6, h: 4 } },
        { type: 'attendance_summary', position: { x: 0, y: 4, w: 4, h: 3 } },
        { type: 'upcoming_deadlines', position: { x: 4, y: 4, w: 8, h: 3 } },
        { type: 'performance_trends', position: { x: 0, y: 7, w: 12, h: 4 } }
      ]
    }
  end
  
  def self.default_teacher_layout
    {
      widgets: [
        { type: 'class_performance', position: { x: 0, y: 0, w: 8, h: 4 } },
        { type: 'assignment_statistics', position: { x: 8, y: 0, w: 4, h: 4 } },
        { type: 'attendance_analytics', position: { x: 0, y: 4, w: 6, h: 4 } },
        { type: 'student_engagement', position: { x: 6, y: 4, w: 6, h: 4 } },
        { type: 'grade_distribution', position: { x: 0, y: 8, w: 6, h: 3 } },
        { type: 'recent_submissions', position: { x: 6, y: 8, w: 6, h: 3 } }
      ]
    }
  end
  
  def self.default_admin_layout
    {
      widgets: [
        { type: 'institutional_overview', position: { x: 0, y: 0, w: 12, h: 3 } },
        { type: 'department_comparison', position: { x: 0, y: 3, w: 8, h: 4 } },
        { type: 'user_activity', position: { x: 8, y: 3, w: 4, h: 4 } },
        { type: 'system_health', position: { x: 0, y: 7, w: 6, h: 3 } },
        { type: 'usage_statistics', position: { x: 6, y: 7, w: 6, h: 3 } }
      ]
    }
  end
  
  # Initialize dashboard with default layout
  def initialize_default_layout
    case dashboard_type
    when 'student'
      self.layout_config = self.class.default_student_layout
    when 'teacher'
      self.layout_config = self.class.default_teacher_layout
    when 'admin'
      self.layout_config = self.class.default_admin_layout
    end
  end
  
  # Get dashboard data for rendering
  def dashboard_data(time_range: 30.days)
    {
      widgets: widget_data(time_range),
      layout: layout_config,
      filters: active_filters,
      permissions: permissions_config
    }
  end
  
  private
  
  def widget_data(time_range)
    return {} unless layout_config&.dig('widgets')
    
    data = {}
    layout_config['widgets'].each do |widget|
      widget_type = widget['type']
      data[widget_type] = generate_widget_data(widget_type, time_range)
    end
    data
  end
  
  def generate_widget_data(widget_type, time_range)
    case widget_type
    when 'grade_overview'
      grade_overview_data(time_range)
    when 'assignment_progress'
      assignment_progress_data(time_range)
    when 'attendance_summary'
      attendance_summary_data(time_range)
    when 'performance_trends'
      performance_trends_data(time_range)
    when 'class_performance'
      class_performance_data(time_range)
    when 'assignment_statistics'
      assignment_statistics_data(time_range)
    when 'attendance_analytics'
      attendance_analytics_data(time_range)
    when 'student_engagement'
      student_engagement_data(time_range)
    else
      {}
    end
  end
  
  def grade_overview_data(time_range)
    return {} unless user.role == 'student'
    
    submissions = user.submissions.joins(:assignment)
                     .where(assignments: { created_at: time_range.ago..Time.current })
                     .where.not(grade: nil)
    
    {
      average_grade: submissions.average(:grade)&.round(2) || 0,
      total_assignments: submissions.count,
      graded_assignments: submissions.where.not(graded_at: nil).count,
      pending_assignments: user.submissions.where(grade: nil).count,
      grade_trend: calculate_grade_trend(submissions)
    }
  end
  
  def assignment_progress_data(time_range)
    return {} unless user.role == 'student'
    
    assignments = Assignment.joins(:submissions)
                           .where(submissions: { user: user })
                           .where(created_at: time_range.ago..Time.current)
    
    {
      completed: assignments.joins(:submissions).where(submissions: { status: 'graded' }).count,
      in_progress: assignments.joins(:submissions).where(submissions: { status: 'submitted' }).count,
      overdue: assignments.where('due_date < ?', Time.current).count,
      upcoming: assignments.where('due_date > ? AND due_date < ?', Time.current, 7.days.from_now).count
    }
  end
  
  def attendance_summary_data(time_range)
    return {} unless user.role == 'student'
    
    records = user.attendance_records.joins(attendance_list: :schedule)
                 .where(schedules: { start_time: time_range.ago..Time.current })
    
    total_classes = Schedule.joins(:attendance_lists)
                           .where(attendance_lists: { created_at: time_range.ago..Time.current })
                           .count
    
    {
      attended_classes: records.count,
      total_classes: total_classes,
      attendance_rate: total_classes > 0 ? (records.count.to_f / total_classes * 100).round(1) : 0,
      late_arrivals: records.where('recorded_at > ?', 10.minutes.ago).count
    }
  end
  
  def performance_trends_data(time_range)
    submissions = case user.role
                 when 'student'
                   user.submissions.where(created_at: time_range.ago..Time.current).where.not(grade: nil)
                 when 'teacher'
                   Submission.joins(:assignment).where(assignments: { user: user }).where.not(grade: nil)
                 else
                   Submission.none
                 end
    
    # Group by week and calculate average grades
    weekly_data = submissions.group_by_week(:created_at).average(:grade)
    
    {
      labels: weekly_data.keys.map { |date| date.strftime('%b %d') },
      data: weekly_data.values.map { |avg| avg&.round(2) || 0 },
      trend_direction: calculate_trend_direction(weekly_data.values)
    }
  end
  
  def class_performance_data(time_range)
    return {} unless user.role == 'teacher'
    
    assignments = user.assignments.where(created_at: time_range.ago..Time.current)
    submissions = Submission.joins(:assignment).where(assignments: { user: user }).where.not(grade: nil)
    
    {
      total_students: submissions.distinct.count(:user_id),
      average_class_grade: submissions.average(:grade)&.round(2) || 0,
      assignments_created: assignments.count,
      submissions_graded: submissions.where.not(graded_at: nil).count,
      grade_distribution: calculate_grade_distribution(submissions)
    }
  end
  
  def assignment_statistics_data(time_range)
    return {} unless user.role == 'teacher'
    
    assignments = user.assignments.where(created_at: time_range.ago..Time.current)
    
    {
      total_assignments: assignments.count,
      avg_submissions_per_assignment: assignments.joins(:submissions).group(:id).count.values.sum.to_f / assignments.count,
      on_time_submission_rate: calculate_on_time_rate(assignments),
      most_challenging_assignment: find_most_challenging_assignment(assignments)
    }
  end
  
  def attendance_analytics_data(time_range)
    return {} unless user.role == 'teacher'
    
    schedules = user.schedules.where(start_time: time_range.ago..Time.current)
    attendance_records = AttendanceRecord.joins(attendance_list: :schedule)
                                        .where(schedules: { user: user })
    
    {
      total_classes: schedules.count,
      average_attendance_rate: calculate_average_attendance_rate(schedules),
      most_attended_class: find_most_attended_class(schedules),
      attendance_trends: calculate_attendance_trends(schedules, time_range)
    }
  end
  
  def student_engagement_data(time_range)
    return {} unless user.role == 'teacher'
    
    # Calculate engagement metrics based on submissions, attendance, and note activity
    students = User.joins(:submissions).where(submissions: { assignment: user.assignments }).distinct
    
    engagement_scores = students.map do |student|
      {
        student_id: student.id,
        name: student.full_name,
        engagement_score: calculate_engagement_score(student, time_range)
      }
    end
    
    {
      highly_engaged: engagement_scores.select { |s| s[:engagement_score] >= 80 }.count,
      moderately_engaged: engagement_scores.select { |s| s[:engagement_score].between?(60, 79) }.count,
      low_engagement: engagement_scores.select { |s| s[:engagement_score] < 60 }.count,
      top_students: engagement_scores.sort_by { |s| s[:engagement_score] }.last(5)
    }
  end
  
  def active_filters
    filter_config || {}
  end
  
  def calculate_grade_trend(submissions)
    return 'stable' if submissions.count < 2
    
    recent_grades = submissions.order(:created_at).last(5).pluck(:grade)
    return 'stable' if recent_grades.count < 2
    
    slope = calculate_slope(recent_grades)
    
    if slope > 2
      'improving'
    elsif slope < -2
      'declining'
    else
      'stable'
    end
  end
  
  def calculate_slope(values)
    n = values.length
    return 0 if n < 2
    
    x_sum = (0...n).sum
    y_sum = values.sum
    xy_sum = values.each_with_index.map { |y, x| x * y }.sum
    x_squared_sum = (0...n).map { |x| x * x }.sum
    
    (n * xy_sum - x_sum * y_sum).to_f / (n * x_squared_sum - x_sum * x_sum)
  end
  
  def calculate_trend_direction(values)
    return 'stable' if values.empty? || values.compact.length < 2
    
    slope = calculate_slope(values.compact)
    
    if slope > 0.5
      'up'
    elsif slope < -0.5
      'down'
    else
      'stable'
    end
  end
  
  def calculate_grade_distribution(submissions)
    grades = submissions.pluck(:grade).compact
    return {} if grades.empty?
    
    {
      'A (90-100)' => grades.count { |g| g >= 90 },
      'B (80-89)' => grades.count { |g| g >= 80 && g < 90 },
      'C (70-79)' => grades.count { |g| g >= 70 && g < 80 },
      'D (60-69)' => grades.count { |g| g >= 60 && g < 70 },
      'F (0-59)' => grades.count { |g| g < 60 }
    }
  end
  
  def calculate_engagement_score(student, time_range)
    # Engagement score based on multiple factors
    submission_score = calculate_submission_engagement(student, time_range)
    attendance_score = calculate_attendance_engagement(student, time_range)
    participation_score = calculate_participation_engagement(student, time_range)
    
    # Weighted average
    (submission_score * 0.4 + attendance_score * 0.4 + participation_score * 0.2).round
  end
  
  def calculate_submission_engagement(student, time_range)
    assignments = user.assignments.where(created_at: time_range.ago..Time.current)
    submissions = student.submissions.joins(:assignment).where(assignments: { user: user })
    
    return 0 if assignments.count == 0
    
    on_time_submissions = submissions.joins(:assignment).where('submissions.submitted_at <= assignments.due_date').count
    (on_time_submissions.to_f / assignments.count * 100).round
  end
  
  def calculate_attendance_engagement(student, time_range)
    schedules = user.schedules.where(start_time: time_range.ago..Time.current)
    attended = AttendanceRecord.joins(attendance_list: :schedule)
                              .where(schedules: { user: user }, user: student).count
    
    return 0 if schedules.count == 0
    
    (attended.to_f / schedules.count * 100).round
  end
  
  def calculate_participation_engagement(student, time_range)
    # Based on note sharing, forum participation, etc.
    notes_shared = student.note_shares.where(created_at: time_range.ago..Time.current).count
    notes_created = student.notes.where(created_at: time_range.ago..Time.current).count
    
    # Simple scoring - can be enhanced with more metrics
    participation_score = (notes_shared * 10 + notes_created * 5)
    [participation_score, 100].min
  end
end