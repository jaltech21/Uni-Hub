class UserActivityService
  def initialize(user)
    @user = user
  end

  def recent_study_sessions
    # Mock data - replace with actual user activity tracking
    [
      {
        date: 2.days.ago,
        duration: 90, # minutes
        subject: 'Mathematics',
        effectiveness_score: 0.8
      },
      {
        date: 1.day.ago,
        duration: 150,
        subject: 'Physics',
        effectiveness_score: 0.6
      }
    ]
  end

  def identify_weak_subjects
    # Analyze performance across subjects
    subjects_performance = calculate_subject_performance
    
    subjects_performance.select { |subject| subject[:score] < 0.7 }
                       .map { |subject| 
                         {
                           id: subject[:id],
                           name: subject[:name],
                           score: subject[:score],
                           urgency: calculate_urgency(subject)
                         }
                       }
  end

  def optimal_study_times
    # Analyze when user is most productive
    activity_by_hour = analyze_hourly_activity
    
    top_hours = activity_by_hour.sort_by { |hour, data| -data[:effectiveness] }
                               .first(3)
                               .map { |hour, _| format_time_period(hour) }
    
    top_hours
  end

  def weekly_productivity_score
    # Calculate productivity score based on goals achieved vs planned
    planned_tasks = @user.tasks.where('created_at > ?', 1.week.ago).count
    completed_tasks = @user.tasks.completed.where('completed_at > ?', 1.week.ago).count
    
    return 0.5 if planned_tasks == 0
    
    completion_rate = completed_tasks.to_f / planned_tasks
    
    # Adjust for quality metrics
    quality_bonus = calculate_quality_bonus
    
    [completion_rate + quality_bonus, 1.0].min
  end

  def procrastination_analysis
    # Identify patterns of procrastination
    task_delays = analyze_task_delays
    
    {
      average_delay: task_delays[:average_delay],
      high_risk_times: identify_procrastination_times,
      common_triggers: identify_procrastination_triggers,
      severity: calculate_procrastination_severity(task_delays)
    }
  end

  def peak_usage_hours
    # When user is most active on the platform
    usage_data = analyze_platform_usage
    
    peak_periods = []
    
    if usage_data[:morning] > 0.3
      peak_periods << 'morning'
    end
    
    if usage_data[:afternoon] > 0.4
      peak_periods << 'afternoon'
    end
    
    if usage_data[:evening] > 0.5
      peak_periods << 'evening'
    end
    
    peak_periods.presence || ['evening'] # default
  end

  def most_used_features
    # Track which features user engages with most
    feature_usage = {
      'calendar' => calculate_feature_usage('calendar'),
      'notes' => calculate_feature_usage('notes'),
      'assignments' => calculate_feature_usage('assignments'),
      'study_groups' => calculate_feature_usage('study_groups'),
      'resources' => calculate_feature_usage('resources')
    }
    
    feature_usage.sort_by { |_, usage| -usage }
               .first(3)
               .map { |feature, _| feature }
  end

  def study_session_patterns
    # Analyze study session characteristics
    sessions = recent_study_sessions
    
    {
      average_duration: sessions.sum { |s| s[:duration] } / sessions.count.to_f,
      preferred_subjects: sessions.group_by { |s| s[:subject] }
                                 .transform_values(&:count)
                                 .sort_by { |_, count| -count }
                                 .first(3)
                                 .map { |subject, _| subject },
      consistency_score: calculate_study_consistency(sessions),
      optimal_duration: calculate_optimal_session_duration(sessions)
    }
  end

  def collaboration_frequency
    # How often user collaborates with others
    study_group_sessions = @user.study_group_participations
                               .where('created_at > ?', 1.month.ago)
                               .count
    
    peer_interactions = @user.discussion_posts
                            .where('created_at > ?', 1.month.ago)
                            .count
    
    case study_group_sessions + peer_interactions
    when 0..2
      'low'
    when 3..8
      'medium'
    else
      'high'
    end
  end

  def rarely_uses_calendar?
    calendar_events = @user.calendar_events
                          .where('created_at > ?', 2.weeks.ago)
                          .count
    
    calendar_events < 3
  end

  private

  def calculate_subject_performance
    # Mock implementation - replace with actual grade/performance data
    @user.courses.map do |course|
      {
        id: course.id,
        name: course.name,
        score: calculate_course_score(course)
      }
    end
  end

  def calculate_course_score(course)
    # Calculate performance score for a course
    assignments = course.assignments.completed
    return 0.5 if assignments.empty?
    
    total_score = assignments.sum(&:score) / assignments.sum(&:max_score).to_f
    total_score.clamp(0.0, 1.0)
  end

  def calculate_urgency(subject)
    # Determine urgency based on upcoming deadlines and current performance
    upcoming_assignments = subject[:assignments]&.select { |a| a[:due_date] <= 1.week.from_now }
    
    case
    when upcoming_assignments&.any? && subject[:score] < 0.5
      'high'
    when upcoming_assignments&.any? || subject[:score] < 0.6
      'medium'
    else
      'low'
    end
  end

  def analyze_hourly_activity
    # Mock data - replace with actual activity tracking
    {
      8 => { effectiveness: 0.9, sessions: 12 },   # 8 AM
      14 => { effectiveness: 0.7, sessions: 8 },   # 2 PM
      20 => { effectiveness: 0.8, sessions: 15 }   # 8 PM
    }
  end

  def format_time_period(hour)
    case hour
    when 6..11
      'morning'
    when 12..17
      'afternoon'
    when 18..23
      'evening'
    else
      'night'
    end
  end

  def calculate_quality_bonus
    # Bonus points for high-quality work completion
    recent_work_quality = @user.assignments
                              .completed
                              .where('completed_at > ?', 1.week.ago)
                              .average(:quality_score) || 0.5
    
    (recent_work_quality - 0.5) * 0.2 # Up to 0.1 bonus
  end

  def analyze_task_delays
    # Analyze how often and by how much tasks are delayed
    tasks = @user.tasks.completed.where('completed_at > ?', 1.month.ago)
    
    delays = tasks.map do |task|
      next 0 if task.due_date.nil? || task.completed_at <= task.due_date
      
      (task.completed_at.to_date - task.due_date.to_date).to_i
    end.compact
    
    {
      average_delay: delays.empty? ? 0 : delays.sum / delays.count.to_f,
      delay_frequency: (delays.count { |d| d > 0 } / tasks.count.to_f),
      max_delay: delays.max || 0
    }
  end

  def identify_procrastination_times
    # Times when user tends to procrastinate most
    delay_data = analyze_task_creation_vs_completion_times
    
    high_delay_periods = delay_data.select { |period, data| data[:avg_delay] > 2 }
                                  .keys
    
    high_delay_periods.presence || ['afternoon'] # default
  end

  def identify_procrastination_triggers
    # Common situations that lead to procrastination
    triggers = []
    
    # Analyze task types that are frequently delayed
    delayed_task_types = @user.tasks.joins(:category)
                             .where('completed_at > due_date')
                             .group('categories.name')
                             .count
    
    if delayed_task_types['study'] > delayed_task_types.values.sum * 0.4
      triggers << 'difficult_subjects'
    end
    
    if delayed_task_types['assignment'] > delayed_task_types.values.sum * 0.3
      triggers << 'large_projects'
    end
    
    triggers.presence || ['deadline_pressure']
  end

  def calculate_procrastination_severity(task_delays)
    avg_delay = task_delays[:average_delay]
    frequency = task_delays[:delay_frequency]
    
    case
    when avg_delay > 5 || frequency > 0.7
      'high'
    when avg_delay > 2 || frequency > 0.4
      'medium'
    else
      'low'
    end
  end

  def analyze_platform_usage
    # Mock data - replace with actual usage analytics
    {
      morning: 0.25,   # 25% of usage in morning
      afternoon: 0.35, # 35% in afternoon
      evening: 0.40    # 40% in evening
    }
  end

  def calculate_feature_usage(feature)
    # Calculate usage frequency for a specific feature
    case feature
    when 'calendar'
      @user.calendar_events.where('created_at > ?', 1.month.ago).count
    when 'notes'
      @user.notes.where('created_at > ?', 1.month.ago).count
    when 'assignments'
      @user.assignment_submissions.where('created_at > ?', 1.month.ago).count
    when 'study_groups'
      @user.study_group_participations.where('created_at > ?', 1.month.ago).count
    when 'resources'
      @user.resource_views.where('created_at > ?', 1.month.ago).count
    else
      0
    end
  end

  def calculate_study_consistency(sessions)
    # Measure how consistently user studies
    return 0 if sessions.empty?
    
    study_days = sessions.map { |s| s[:date].to_date }.uniq.count
    total_days = (sessions.first[:date].to_date..Date.current).count
    
    study_days.to_f / total_days
  end

  def calculate_optimal_session_duration(sessions)
    # Find the session duration that correlates with highest effectiveness
    duration_effectiveness = sessions.group_by { |s| (s[:duration] / 30) * 30 } # Group by 30-min intervals
                                   .transform_values { |group| group.sum { |s| s[:effectiveness_score] } / group.count }
    
    optimal_duration_range = duration_effectiveness.max_by { |_, effectiveness| effectiveness }&.first
    
    optimal_duration_range || 60 # default to 60 minutes
  end

  def analyze_task_creation_vs_completion_times
    # Mock data showing when tasks are created vs completed
    {
      'morning' => { avg_delay: 1.5, task_count: 20 },
      'afternoon' => { avg_delay: 3.2, task_count: 35 },
      'evening' => { avg_delay: 1.8, task_count: 25 }
    }
  end
end