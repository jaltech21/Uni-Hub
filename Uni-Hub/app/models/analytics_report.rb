class AnalyticsReport < ApplicationRecord
  belongs_to :user
  belongs_to :department, optional: true
  belongs_to :analytics_dashboard, optional: true
  
  validates :title, presence: true, length: { maximum: 200 }
  validates :report_type, presence: true, inclusion: { 
    in: %w[student_performance class_analytics attendance_report assignment_summary
           department_overview institutional_metrics custom_report scheduled_report],
    message: "%{value} is not a valid report type" 
  }
  validates :status, inclusion: { in: %w[draft generating completed failed scheduled] }
  
  # Report configuration and data stored as JSON
  serialize :config, JSON
  serialize :filters, JSON
  serialize :data, JSON
  serialize :metadata, JSON
  
  scope :by_type, ->(type) { where(report_type: type) if type.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :scheduled, -> { where(report_type: 'scheduled_report') }
  
  # Report generation
  def generate_report!
    update!(status: 'generating', started_at: Time.current)
    
    begin
      report_data = case report_type
                   when 'student_performance'
                     generate_student_performance_report
                   when 'class_analytics'
                     generate_class_analytics_report
                   when 'attendance_report'
                     generate_attendance_report
                   when 'assignment_summary'
                     generate_assignment_summary_report
                   when 'department_overview'
                     generate_department_overview_report
                   when 'institutional_metrics'
                     generate_institutional_metrics_report
                   when 'custom_report'
                     generate_custom_report
                   else
                     {}
                   end
      
      update!(
        status: 'completed',
        data: report_data,
        completed_at: Time.current,
        metadata: generate_metadata(report_data)
      )
      
      # Send notification if requested
      send_completion_notification if config&.dig('notify_on_completion')
      
    rescue StandardError => e
      update!(
        status: 'failed',
        error_message: e.message,
        completed_at: Time.current
      )
      Rails.logger.error "Report generation failed: #{e.message}"
    end
  end
  
  # Export report in various formats
  def export(format: 'pdf')
    case format.to_s.downcase
    when 'pdf'
      generate_pdf
    when 'excel'
      generate_excel
    when 'csv'
      generate_csv
    when 'json'
      data.to_json
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end
  
  # Schedule report for regular generation
  def self.schedule_report(user:, config:, frequency:)
    report = create!(
      user: user,
      title: "Scheduled #{config[:report_type].humanize}",
      report_type: 'scheduled_report',
      status: 'scheduled',
      config: config.merge(
        frequency: frequency,
        next_run: calculate_next_run(frequency)
      )
    )
    
    # Enqueue background job for scheduled generation
    ScheduledReportJob.set(wait_until: report.config['next_run']).perform_later(report.id)
    
    report
  end
  
  # Get report summary statistics
  def summary_stats
    return {} unless completed? && data.present?
    
    {
      total_records: calculate_total_records,
      date_range: "#{filters&.dig('start_date')} - #{filters&.dig('end_date')}",
      generated_at: completed_at,
      file_size: metadata&.dig('file_size'),
      processing_time: calculate_processing_time
    }
  end
  
  private
  
  def generate_student_performance_report
    students = get_filtered_students
    time_range = get_time_range
    
    performance_data = students.map do |student|
      {
        student_id: student.id,
        name: student.full_name,
        email: student.email,
        department: student.department&.name,
        overall_grade: calculate_overall_grade(student, time_range),
        assignment_completion_rate: calculate_completion_rate(student, time_range),
        attendance_rate: calculate_attendance_rate(student, time_range),
        engagement_score: calculate_engagement_score(student, time_range),
        assignments: get_assignment_details(student, time_range),
        attendance_records: get_attendance_details(student, time_range)
      }
    end
    
    {
      students: performance_data,
      summary: {
        total_students: students.count,
        average_grade: performance_data.map { |s| s[:overall_grade] }.compact.sum / performance_data.count,
        average_attendance: performance_data.map { |s| s[:attendance_rate] }.compact.sum / performance_data.count,
        high_performers: performance_data.count { |s| s[:overall_grade] >= 90 },
        at_risk_students: performance_data.count { |s| s[:overall_grade] < 60 }
      }
    }
  end
  
  def generate_class_analytics_report
    classes = get_filtered_classes
    time_range = get_time_range
    
    class_data = classes.map do |schedule|
      {
        class_id: schedule.id,
        title: schedule.title,
        course: schedule.course,
        instructor: schedule.user.full_name,
        enrollment_count: schedule.participants.count,
        attendance_rate: calculate_class_attendance_rate(schedule, time_range),
        assignment_count: get_class_assignments(schedule).count,
        average_grade: calculate_class_average_grade(schedule, time_range),
        engagement_metrics: calculate_class_engagement(schedule, time_range)
      }
    end
    
    {
      classes: class_data,
      summary: {
        total_classes: classes.count,
        total_enrollment: class_data.sum { |c| c[:enrollment_count] },
        average_attendance: class_data.map { |c| c[:attendance_rate] }.sum / class_data.count,
        top_performing_class: class_data.max_by { |c| c[:average_grade] }
      }
    }
  end
  
  def generate_attendance_report
    time_range = get_time_range
    attendance_records = get_filtered_attendance_records(time_range)
    
    daily_stats = attendance_records.group_by { |r| r.recorded_at.to_date }.map do |date, records|
      {
        date: date,
        total_attendance: records.count,
        unique_students: records.map(&:user_id).uniq.count,
        late_arrivals: records.select { |r| r.recorded_at > r.attendance_list.schedule.start_time + 10.minutes }.count
      }
    end
    
    student_stats = attendance_records.group_by(&:user).map do |student, records|
      {
        student_name: student.full_name,
        total_classes_attended: records.count,
        attendance_rate: calculate_student_attendance_rate(student, time_range),
        average_arrival_time: calculate_average_arrival_time(records)
      }
    end
    
    {
      daily_statistics: daily_stats,
      student_statistics: student_stats,
      summary: {
        total_attendance_records: attendance_records.count,
        average_daily_attendance: daily_stats.map { |d| d[:total_attendance] }.sum / daily_stats.count,
        most_attended_day: daily_stats.max_by { |d| d[:total_attendance] }
      }
    }
  end
  
  def generate_assignment_summary_report
    assignments = get_filtered_assignments
    time_range = get_time_range
    
    assignment_data = assignments.map do |assignment|
      submissions = assignment.submissions.where(created_at: time_range)
      
      {
        assignment_id: assignment.id,
        title: assignment.title,
        category: assignment.category,
        due_date: assignment.due_date,
        total_submissions: submissions.count,
        graded_submissions: submissions.where.not(grade: nil).count,
        average_grade: submissions.where.not(grade: nil).average(:grade)&.round(2),
        on_time_submissions: submissions.where('submitted_at <= ?', assignment.due_date).count,
        late_submissions: submissions.where('submitted_at > ?', assignment.due_date).count,
        grade_distribution: calculate_assignment_grade_distribution(submissions)
      }
    end
    
    {
      assignments: assignment_data,
      summary: {
        total_assignments: assignments.count,
        total_submissions: assignment_data.sum { |a| a[:total_submissions] },
        overall_average_grade: assignment_data.map { |a| a[:average_grade] }.compact.sum / assignment_data.count,
        on_time_rate: calculate_overall_on_time_rate(assignment_data)
      }
    }
  end
  
  def generate_department_overview_report
    department = self.department || user.department
    return {} unless department
    
    time_range = get_time_range
    
    {
      department_info: {
        name: department.name,
        code: department.code,
        total_members: department.all_members.count,
        active_teachers: department.teaching_users.count,
        enrolled_students: department.users.where(role: 'student').count
      },
      academic_metrics: {
        total_assignments: department.assignments.where(created_at: time_range).count,
        total_submissions: Submission.joins(:assignment).where(assignments: { department: department }).count,
        average_grade: calculate_department_average_grade(department, time_range),
        attendance_rate: calculate_department_attendance_rate(department, time_range)
      },
      activity_summary: {
        notes_created: department.notes.where(created_at: time_range).count,
        schedules_created: Schedule.where(department: department, created_at: time_range).count,
        active_users: get_active_users_count(department, time_range)
      }
    }
  end
  
  def generate_institutional_metrics_report
    return {} unless user.role == 'admin'
    
    time_range = get_time_range
    
    {
      institutional_overview: {
        total_departments: Department.active.count,
        total_users: User.where(created_at: ..time_range.end).count,
        total_students: User.where(role: 'student', created_at: ..time_range.end).count,
        total_teachers: User.where(role: 'teacher', created_at: ..time_range.end).count
      },
      academic_activity: {
        assignments_created: Assignment.where(created_at: time_range).count,
        submissions_received: Submission.where(created_at: time_range).count,
        classes_scheduled: Schedule.where(created_at: time_range).count,
        attendance_records: AttendanceRecord.where(created_at: time_range).count
      },
      engagement_metrics: {
        notes_created: Note.where(created_at: time_range).count,
        notes_shared: NoteShare.where(created_at: time_range).count,
        active_users_percentage: calculate_active_users_percentage(time_range)
      },
      system_health: {
        average_response_time: calculate_average_response_time,
        uptime_percentage: calculate_uptime_percentage,
        error_rate: calculate_error_rate(time_range)
      }
    }
  end
  
  def generate_custom_report
    # Custom report based on user-defined configuration
    custom_config = config&.dig('custom_settings') || {}
    
    # This would be highly configurable based on user requirements
    # For now, return a basic structure
    {
      custom_data: "Custom report functionality would be implemented based on specific requirements",
      config: custom_config
    }
  end
  
  def get_filtered_students
    scope = User.where(role: 'student')
    scope = scope.where(department: department) if department
    scope = scope.where(id: filters['student_ids']) if filters&.dig('student_ids')
    scope
  end
  
  def get_filtered_classes
    scope = Schedule.all
    scope = scope.where(department: department) if department
    scope = scope.where(user: user) if user.role == 'teacher'
    scope = scope.where(id: filters['class_ids']) if filters&.dig('class_ids')
    scope
  end
  
  def get_filtered_assignments
    scope = Assignment.all
    scope = scope.where(department: department) if department
    scope = scope.where(user: user) if user.role == 'teacher'
    scope = scope.where(id: filters['assignment_ids']) if filters&.dig('assignment_ids')
    scope.where(created_at: get_time_range)
  end
  
  def get_filtered_attendance_records(time_range)
    scope = AttendanceRecord.joins(attendance_list: :schedule).where(created_at: time_range)
    scope = scope.where(schedules: { department: department }) if department
    scope = scope.where(schedules: { user: user }) if user.role == 'teacher'
    scope
  end
  
  def get_time_range
    start_date = filters&.dig('start_date')&.to_date || 30.days.ago
    end_date = filters&.dig('end_date')&.to_date || Date.current
    start_date..end_date
  end
  
  def calculate_total_records
    return 0 unless data.present?
    
    case report_type
    when 'student_performance'
      data.dig('students')&.count || 0
    when 'class_analytics'
      data.dig('classes')&.count || 0
    when 'attendance_report'
      data.dig('daily_statistics')&.count || 0
    when 'assignment_summary'
      data.dig('assignments')&.count || 0
    else
      0
    end
  end
  
  def calculate_processing_time
    return nil unless started_at && completed_at
    ((completed_at - started_at) * 1000).round(2) # in milliseconds
  end
  
  def generate_metadata(report_data)
    {
      record_count: calculate_total_records,
      data_size: report_data.to_json.bytesize,
      filters_applied: filters&.keys || [],
      generation_time: calculate_processing_time
    }
  end
  
  def send_completion_notification
    ReportMailer.completion_notification(self).deliver_later
  end
  
  def self.calculate_next_run(frequency)
    case frequency
    when 'daily'
      1.day.from_now
    when 'weekly'
      1.week.from_now
    when 'monthly'
      1.month.from_now
    else
      1.week.from_now
    end
  end
end