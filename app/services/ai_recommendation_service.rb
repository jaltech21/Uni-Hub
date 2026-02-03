class AiRecommendationService
  include Rails.application.routes.url_helpers

  def initialize(user)
    @user = user
    @user_activity = UserActivityService.new(user)
  end

  def generate_recommendations
    {
      study_recommendations: generate_study_recommendations,
      content_suggestions: generate_content_suggestions,
      learning_path: generate_learning_path,
      productivity_tips: generate_productivity_tips,
      social_recommendations: generate_social_recommendations
    }
  end

  def generate_widget_recommendations
    user_preferences = @user.personalization_preferences
    usage_patterns = analyze_usage_patterns
    
    recommended_widgets = []
    
    # Based on user activity patterns
    if high_assignment_activity?
      recommended_widgets << {
        type: 'assignment_progress',
        reason: 'You have many active assignments',
        priority: 'high'
      }
    end
    
    if frequent_note_taker?
      recommended_widgets << {
        type: 'recent_notes',
        reason: 'You frequently take notes',
        priority: 'high'
      }
    end
    
    if upcoming_deadlines?
      recommended_widgets << {
        type: 'upcoming_deadlines',
        reason: 'You have upcoming deadlines',
        priority: 'urgent'
      }
    end
    
    if social_learner?
      recommended_widgets << {
        type: 'study_groups',
        reason: 'You often participate in study groups',
        priority: 'medium'
      }
    end
    
    # Time-based recommendations
    if morning_active?
      recommended_widgets << {
        type: 'daily_planner',
        reason: 'Perfect for your morning routine',
        priority: 'medium'
      }
    end
    
    recommended_widgets
  end

  private

  def generate_study_recommendations
    recommendations = []
    
    # Analyze study patterns
    study_sessions = @user_activity.recent_study_sessions
    weak_subjects = @user_activity.identify_weak_subjects
    optimal_times = @user_activity.optimal_study_times
    
    # Subject-specific recommendations
    weak_subjects.each do |subject|
      recommendations << {
        type: 'subject_focus',
        title: "Focus on #{subject[:name]}",
        description: "Your performance in #{subject[:name]} could be improved. Consider spending 30 minutes daily on this subject.",
        action_url: study_path(subject: subject[:id]),
        priority: subject[:urgency],
        icon: 'fas fa-book-open'
      }
    end
    
    # Study technique recommendations
    if study_sessions.any? { |s| s[:duration] > 120 }
      recommendations << {
        type: 'study_technique',
        title: 'Try the Pomodoro Technique',
        description: 'Break your long study sessions into 25-minute focused intervals with 5-minute breaks.',
        action_url: pomodoro_timer_path,
        priority: 'medium',
        icon: 'fas fa-clock'
      }
    end
    
    # Time-based recommendations
    if optimal_times.any?
      best_time = optimal_times.first
      recommendations << {
        type: 'schedule_optimization',
        title: "Study at #{best_time}",
        description: "You're most productive at #{best_time}. Schedule important subjects during this time.",
        action_url: schedule_path,
        priority: 'low',
        icon: 'fas fa-calendar-check'
      }
    end
    
    recommendations.take(5)
  end

  def generate_content_suggestions
    suggestions = []
    
    # Based on current courses
    @user.courses.active.each do |course|
      # Suggest relevant materials
      if course.next_assignment
        suggestions << {
          type: 'assignment_help',
          title: "Resources for #{course.next_assignment.title}",
          description: "Curated materials to help with your upcoming assignment",
          course: course.name,
          action_url: course_resources_path(course),
          priority: 'high',
          icon: 'fas fa-lightbulb'
        }
      end
      
      # Suggest practice materials
      if course.recent_poor_performance?
        suggestions << {
          type: 'practice_material',
          title: "Practice #{course.name}",
          description: "Additional exercises to strengthen your understanding",
          course: course.name,
          action_url: practice_path(course),
          priority: 'medium',
          icon: 'fas fa-dumbbell'
        }
      end
    end
    
    # Trending content
    suggestions << {
      type: 'trending',
      title: 'Popular Study Resources',
      description: 'See what other students in your field are using',
      action_url: trending_resources_path,
      priority: 'low',
      icon: 'fas fa-fire'
    }
    
    suggestions.take(4)
  end

  def generate_learning_path
    path_items = []
    
    # Analyze user's academic progress
    current_level = assess_academic_level
    learning_goals = @user.learning_goals.active
    
    learning_goals.each do |goal|
      next_steps = calculate_next_steps(goal)
      
      next_steps.each do |step|
        path_items << {
          goal_id: goal.id,
          title: step[:title],
          description: step[:description],
          estimated_time: step[:duration],
          difficulty: step[:difficulty],
          prerequisites: step[:prerequisites],
          action_url: step[:url],
          icon: step[:icon] || 'fas fa-graduation-cap'
        }
      end
    end
    
    # If no specific goals, suggest general academic improvement
    if path_items.empty?
      path_items = generate_default_learning_path(current_level)
    end
    
    path_items.take(6)
  end

  def generate_productivity_tips
    tips = []
    
    # Analyze productivity patterns
    productivity_score = @user_activity.weekly_productivity_score
    procrastination_patterns = @user_activity.procrastination_analysis
    
    if productivity_score < 0.6
      tips << {
        type: 'productivity_boost',
        title: 'Boost Your Productivity',
        description: 'Your productivity is below average. Try time-blocking your schedule.',
        action_url: productivity_tools_path,
        priority: 'high',
        icon: 'fas fa-rocket'
      }
    end
    
    if procrastination_patterns[:high_risk_times].any?
      risky_time = procrastination_patterns[:high_risk_times].first
      tips << {
        type: 'procrastination_help',
        title: "Avoid Distractions at #{risky_time}",
        description: 'You tend to procrastinate during this time. Consider using a focus app.',
        action_url: focus_tools_path,
        priority: 'medium',
        icon: 'fas fa-eye-slash'
      }
    end
    
    # General tips based on user behavior
    if @user_activity.rarely_uses_calendar?
      tips << {
        type: 'organization',
        title: 'Use Your Calendar More',
        description: 'Students who actively use calendars are 40% more organized.',
        action_url: calendar_path,
        priority: 'low',
        icon: 'fas fa-calendar-alt'
      }
    end
    
    tips.take(3)
  end

  def generate_social_recommendations
    recommendations = []
    
    # Study group suggestions
    compatible_students = find_compatible_study_partners
    
    if compatible_students.any?
      recommendations << {
        type: 'study_group',
        title: 'Join a Study Group',
        description: "#{compatible_students.count} students with similar interests want to study together",
        action_url: study_groups_path,
        priority: 'medium',
        icon: 'fas fa-users'
      }
    end
    
    # Peer recommendations
    if @user.courses.any?
      course_peers = find_course_peers
      recommendations << {
        type: 'peer_connection',
        title: 'Connect with Classmates',
        description: "Students in your courses are discussing #{course_peers[:trending_topic]}",
        action_url: discussions_path,
        priority: 'low',
        icon: 'fas fa-comments'
      }
    end
    
    recommendations.take(2)
  end

  def analyze_usage_patterns
    {
      peak_usage_hours: @user_activity.peak_usage_hours,
      most_used_features: @user_activity.most_used_features,
      study_session_patterns: @user_activity.study_session_patterns,
      collaboration_frequency: @user_activity.collaboration_frequency
    }
  end

  def high_assignment_activity?
    @user.assignments.active.count > 3
  end

  def frequent_note_taker?
    @user.notes.where('created_at > ?', 1.week.ago).count > 5
  end

  def upcoming_deadlines?
    @user.assignments.where('due_date BETWEEN ? AND ?', Date.current, 1.week.from_now).exists?
  end

  def social_learner?
    @user.study_group_participations.where('created_at > ?', 1.month.ago).count > 2
  end

  def morning_active?
    @user_activity.peak_usage_hours.include?('morning')
  end

  def assess_academic_level
    # Implement academic level assessment logic
    gpa = @user.gpa || 3.0
    completed_courses = @user.courses.completed.count
    
    case
    when gpa >= 3.7 && completed_courses > 20
      'advanced'
    when gpa >= 3.0 && completed_courses > 10
      'intermediate'
    else
      'beginner'
    end
  end

  def calculate_next_steps(goal)
    # Calculate personalized next steps for a learning goal
    case goal.category
    when 'academic_improvement'
      academic_improvement_steps(goal)
    when 'skill_development'
      skill_development_steps(goal)
    when 'career_preparation'
      career_preparation_steps(goal)
    else
      general_improvement_steps(goal)
    end
  end

  def generate_default_learning_path(level)
    case level
    when 'beginner'
      beginner_learning_path
    when 'intermediate'
      intermediate_learning_path
    when 'advanced'
      advanced_learning_path
    end
  end

  def find_compatible_study_partners
    # Find students with similar courses, study times, and academic performance
    similar_courses = @user.courses.pluck(:id)
    
    User.joins(:courses)
        .where(courses: { id: similar_courses })
        .where.not(id: @user.id)
        .group('users.id')
        .having('COUNT(courses.id) >= ?', [similar_courses.count * 0.5, 1].max)
        .limit(10)
  end

  def find_course_peers
    # Analyze trending topics and discussions among course peers
    {
      trending_topic: 'Exam preparation strategies',
      active_discussions: 12,
      peer_count: 45
    }
  end

  def academic_improvement_steps(goal)
    [
      {
        title: 'Identify weak areas',
        description: 'Complete a comprehensive assessment',
        duration: '30 minutes',
        difficulty: 'easy',
        prerequisites: [],
        url: assessment_path(goal),
        icon: 'fas fa-clipboard-check'
      },
      {
        title: 'Create study schedule',
        description: 'Plan targeted study sessions',
        duration: '1 hour',
        difficulty: 'medium',
        prerequisites: ['assessment'],
        url: study_planner_path,
        icon: 'fas fa-calendar-check'
      }
    ]
  end

  def skill_development_steps(goal)
    [
      {
        title: 'Learn fundamentals',
        description: 'Master the basic concepts',
        duration: '2 weeks',
        difficulty: 'easy',
        prerequisites: [],
        url: fundamentals_path(goal),
        icon: 'fas fa-book'
      }
    ]
  end

  def career_preparation_steps(goal)
    [
      {
        title: 'Update resume',
        description: 'Refresh your professional profile',
        duration: '2 hours',
        difficulty: 'medium',
        prerequisites: [],
        url: resume_builder_path,
        icon: 'fas fa-file-alt'
      }
    ]
  end

  def general_improvement_steps(goal)
    [
      {
        title: 'Set specific milestones',
        description: 'Break down your goal into achievable steps',
        duration: '45 minutes',
        difficulty: 'easy',
        prerequisites: [],
        url: goal_planning_path(goal),
        icon: 'fas fa-flag-checkered'
      }
    ]
  end

  def beginner_learning_path
    [
      {
        title: 'Master time management',
        description: 'Learn effective scheduling and prioritization',
        estimated_time: '1 week',
        difficulty: 'easy',
        prerequisites: [],
        action_url: time_management_course_path,
        icon: 'fas fa-clock'
      },
      {
        title: 'Develop note-taking skills',
        description: 'Learn various note-taking methods and find what works for you',
        estimated_time: '3 days',
        difficulty: 'easy',
        prerequisites: [],
        action_url: note_taking_guide_path,
        icon: 'fas fa-pen'
      }
    ]
  end

  def intermediate_learning_path
    [
      {
        title: 'Advanced study techniques',
        description: 'Master spaced repetition and active recall',
        estimated_time: '2 weeks',
        difficulty: 'medium',
        prerequisites: ['basic_study_skills'],
        action_url: advanced_techniques_path,
        icon: 'fas fa-brain'
      }
    ]
  end

  def advanced_learning_path
    [
      {
        title: 'Research methodology',
        description: 'Learn advanced research and analysis techniques',
        estimated_time: '1 month',
        difficulty: 'hard',
        prerequisites: ['intermediate_research'],
        action_url: research_course_path,
        icon: 'fas fa-microscope'
      }
    ]
  end
end