module DashboardHelper
  def widget_icon(widget_type)
    case widget_type.to_s
    when 'recent_activity'
      'fas fa-clock'
    when 'quick_stats'
      'fas fa-chart-bar'
    when 'upcoming_deadlines'
      'fas fa-calendar-alt'
    when 'recent_notes'
      'fas fa-sticky-note'
    when 'assignment_progress'
      'fas fa-tasks'
    when 'communication_overview'
      'fas fa-comments'
    when 'calendar_preview'
      'fas fa-calendar'
    when 'grade_overview'
      'fas fa-graduation-cap'
    when 'discussion_feed'
      'fas fa-users'
    when 'learning_insights'
      'fas fa-lightbulb'
    when 'weather'
      'fas fa-cloud-sun'
    when 'quick_actions'
      'fas fa-bolt'
    when 'ai_recommendations'
      'fas fa-brain'
    when 'calendar'
      'fas fa-calendar-check'
    when 'study_groups'
      'fas fa-users-cog'
    when 'resources'
      'fas fa-book-open'
    when 'notifications'
      'fas fa-bell'
    when 'daily_planner'
      'fas fa-list-check'
    else
      'fas fa-th'
    end
  end

  def widget_description(widget_type)
    case widget_type.to_s
    when 'recent_activity'
      'View your latest activities and updates'
    when 'quick_stats'
      'Overview of your key statistics and metrics'
    when 'upcoming_deadlines'
      'Never miss an important deadline'
    when 'recent_notes'
      'Quick access to your recent notes and documents'
    when 'assignment_progress'
      'Track your assignment completion progress'
    when 'communication_overview'
      'Messages, notifications, and communication summary'
    when 'calendar_preview'
      'Upcoming events and schedule overview'
    when 'grade_overview'
      'Current grades and academic performance'
    when 'discussion_feed'
      'Latest discussions and forum updates'
    when 'learning_insights'
      'AI-powered insights and recommendations'
    when 'weather'
      'Current weather and forecast'
    when 'quick_actions'
      'Shortcuts to frequently used features'
    when 'ai_recommendations'
      'Personalized AI-powered learning recommendations and study insights'
    when 'calendar'
      'Your schedule and upcoming events'
    when 'study_groups'
      'Connect with study partners and groups'
    when 'resources'
      'Learning resources and materials'
    when 'notifications'
      'Important alerts and updates'
    when 'daily_planner'
      'Plan and organize your daily tasks'
    else
      'Dashboard widget'
    end
  end

  def widget_size_class(widget)
    "grid-w-#{widget.width} grid-h-#{widget.height}"
  end

  def widget_position_style(widget)
    {
      'grid-column': "#{widget.grid_x} / span #{widget.width}",
      'grid-row': "#{widget.grid_y} / span #{widget.height}"
    }.map { |k, v| "#{k}: #{v}" }.join('; ')
  end
end
