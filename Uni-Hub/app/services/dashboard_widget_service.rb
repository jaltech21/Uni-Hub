# app/services/dashboard_widget_service.rb
class DashboardWidgetService
  def initialize(user)
    @user = user
  end
  
  def get_widget_data(widget, force_refresh: false)
    # Return cached data unless force refresh or data is stale
    if !force_refresh && !widget.needs_refresh?
      return get_cached_widget_data(widget)
    end
    
    data = case widget.widget_type
    when 'recent_activity'
      get_recent_activity_data(widget)
    when 'quick_stats'
      get_quick_stats_data(widget)
    when 'upcoming_deadlines'
      get_upcoming_deadlines_data(widget)
    when 'recent_notes'
      get_recent_notes_data(widget)
    when 'assignment_progress'
      get_assignment_progress_data(widget)
    when 'communication_overview'
      get_communication_overview_data(widget)
    when 'calendar_preview'
      get_calendar_preview_data(widget)
    when 'grade_overview'
      get_grade_overview_data(widget)
    when 'discussion_feed'
      get_discussion_feed_data(widget)
    when 'learning_insights'
      get_learning_insights_data(widget)
    when 'weather'
      get_weather_data(widget)
    when 'quick_actions'
      get_quick_actions_data(widget)
    else
      { error: 'Unknown widget type' }
    end
    
    # Cache the data
    cache_widget_data(widget, data)
    data
  end
  
  private
  
  def get_recent_activity_data(widget)
    config = widget.configuration_with_defaults
    limit = config['limit'] || 10
    
    activities = []
    
    # Recent notes
    recent_notes = @user.notes.order(updated_at: :desc).limit(3)
    recent_notes.each do |note|
      activities << {
        type: 'note',
        title: note.title,
        action: 'updated',
        time: note.updated_at,
        url: "/notes/#{note.id}",
        icon: 'document-text'
      }
    end
    
    # Recent assignments (for students)
    if @user.student?
      recent_submissions = @user.submissions.includes(:assignment).order(created_at: :desc).limit(3)
      recent_submissions.each do |submission|
        activities << {
          type: 'assignment',
          title: submission.assignment.title,
          action: 'submitted',
          time: submission.created_at,
          url: "/assignments/#{submission.assignment.id}",
          icon: 'academic-cap'
        }
      end
    end
    
    # Recent messages
    recent_messages = @user.received_messages.includes(:sender).order(created_at: :desc).limit(3)
    recent_messages.each do |message|
      activities << {
        type: 'message',
        title: "Message from #{message.sender.name}",
        action: 'received',
        time: message.created_at,
        url: "/messages/#{message.sender.id}",
        icon: 'chat-bubble'
      }
    end
    
    # Sort by time and limit
    activities = activities.sort_by { |a| a[:time] }.reverse.first(limit)
    
    {
      activities: activities,
      total_count: activities.length,
      last_updated: Time.current
    }
  end
  
  def get_quick_stats_data(widget)
    if @user.student?
      {
        stats: [
          {
            label: 'Total Notes',
            value: @user.notes.count,
            trend: '+12%',
            trend_positive: true,
            icon: 'document-text',
            color: 'blue'
          },
          {
            label: 'Assignments Due',
            value: Assignment.where('due_date > ?', Time.current)
                            .where.not(id: @user.submissions.pluck(:assignment_id))
                            .count,
            trend: '-2',
            trend_positive: true,
            icon: 'academic-cap',
            color: 'orange'
          },
          {
            label: 'Avg Grade',
            value: @user.submissions.where(status: 'graded').average(:grade)&.round(1) || 0,
            trend: '+5%',
            trend_positive: true,
            icon: 'star',
            color: 'green'
          },
          {
            label: 'Study Streak',
            value: calculate_study_streak,
            unit: 'days',
            trend: '+3',
            trend_positive: true,
            icon: 'fire',
            color: 'red'
          }
        ],
        last_updated: Time.current
      }
    else # teacher
      {
        stats: [
          {
            label: 'Total Assignments',
            value: @user.assignments.count,
            trend: '+2',
            trend_positive: true,
            icon: 'academic-cap',
            color: 'blue'
          },
          {
            label: 'Pending Reviews',
            value: Submission.joins(:assignment)
                            .where(assignments: { user_id: @user.id })
                            .where(status: 'submitted')
                            .count,
            trend: '-5',
            trend_positive: true,
            icon: 'clock',
            color: 'orange'
          },
          {
            label: 'Total Students',
            value: Schedule.where(user_id: @user.id)
                          .or(Schedule.where(instructor_id: @user.id))
                          .sum(&:student_count),
            trend: '+8',
            trend_positive: true,
            icon: 'users',
            color: 'green'
          },
          {
            label: 'Avg Class Rating',
            value: 4.8, # This would come from a ratings system
            trend: '+0.2',
            trend_positive: true,
            icon: 'star',
            color: 'yellow'
          }
        ],
        last_updated: Time.current
      }
    end
  end
  
  def get_upcoming_deadlines_data(widget)
    config = widget.configuration_with_defaults
    days_ahead = config['days_ahead'] || 7
    
    deadlines = []
    
    # Assignment deadlines
    assignments = Assignment.where('due_date > ? AND due_date <= ?', 
                                  Time.current, 
                                  days_ahead.days.from_now)
                           .order(:due_date)
    
    assignments.each do |assignment|
      deadlines << {
        type: 'assignment',
        title: assignment.title,
        due_date: assignment.due_date,
        priority: calculate_deadline_priority(assignment.due_date),
        url: "/assignments/#{assignment.id}",
        icon: 'academic-cap'
      }
    end
    
    # Quiz deadlines (if applicable)
    if @user.quizzes.exists?
      quizzes = @user.quizzes.where('created_at > ?', days_ahead.days.from_now)
      quizzes.each do |quiz|
        deadlines << {
          type: 'quiz',
          title: quiz.title,
          due_date: quiz.created_at + 1.week, # Assuming quizzes are due 1 week after creation
          priority: 'medium',
          url: "/quizzes/#{quiz.id}",
          icon: 'question-mark-circle'
        }
      end
    end
    
    {
      deadlines: deadlines.sort_by { |d| d[:due_date] },
      total_count: deadlines.length,
      overdue_count: 0, # This would be calculated based on actual overdue items
      last_updated: Time.current
    }
  end
  
  def get_recent_notes_data(widget)
    config = widget.configuration_with_defaults
    limit = config['limit'] || 5
    sort_by = config['sort_by'] || 'updated_at'
    
    notes = @user.notes.order("#{sort_by} DESC").limit(limit)
    
    {
      notes: notes.map do |note|
        {
          id: note.id,
          title: note.title,
          preview: note.content&.truncate(100) || 'No content',
          updated_at: note.updated_at,
          tags: note.tags&.pluck(:name) || [],
          url: "/notes/#{note.id}"
        }
      end,
      total_count: @user.notes.count,
      last_updated: Time.current
    }
  end
  
  def get_assignment_progress_data(widget)
    if @user.student?
      total_assignments = Assignment.count
      submitted = @user.submissions.count
      graded = @user.submissions.where(status: 'graded').count
      pending = submitted - graded
      
      {
        progress: {
          total: total_assignments,
          submitted: submitted,
          graded: graded,
          pending: pending,
          completion_rate: total_assignments > 0 ? (submitted.to_f / total_assignments * 100).round(1) : 0
        },
        chart_data: [
          { label: 'Completed', value: graded, color: '#10B981' },
          { label: 'Pending', value: pending, color: '#F59E0B' },
          { label: 'Not Started', value: total_assignments - submitted, color: '#EF4444' }
        ],
        last_updated: Time.current
      }
    else
      # Teacher view
      created_assignments = @user.assignments.count
      total_submissions = Submission.joins(:assignment).where(assignments: { user_id: @user.id }).count
      graded_submissions = Submission.joins(:assignment).where(assignments: { user_id: @user.id }).where(submissions: { status: 'graded' }).count
      pending_review = total_submissions - graded_submissions
      
      {
        progress: {
          created: created_assignments,
          total_submissions: total_submissions,
          graded: graded_submissions,
          pending_review: pending_review,
          grading_rate: total_submissions > 0 ? (graded_submissions.to_f / total_submissions * 100).round(1) : 0
        },
        chart_data: [
          { label: 'Graded', value: graded_submissions, color: '#10B981' },
          { label: 'Pending Review', value: pending_review, color: '#F59E0B' }
        ],
        last_updated: Time.current
      }
    end
  end
  
  def get_communication_overview_data(widget)
    config = widget.configuration_with_defaults
    limit = config['limit'] || 8
    
    conversations = []
    
    # Recent messages
    recent_conversations = ChatMessage.where(
      '(sender_id = ? OR recipient_id = ?)', @user.id, @user.id
    ).includes(:sender, :recipient)
     .group_by { |msg| [msg.sender_id, msg.recipient_id].sort }
     .values
     .map(&:first)
     .sort_by(&:created_at)
     .reverse
     .first(limit)
    
    recent_conversations.each do |message|
      other_user = message.sender == @user ? message.recipient : message.sender
      conversations << {
        user: {
          id: other_user.id,
          name: other_user.name,
          avatar: other_user.email # Could be enhanced with actual avatars
        },
        last_message: {
          content: message.content.truncate(50),
          time: message.created_at,
          unread: message.recipient == @user && !message.read
        },
        url: "/messages/#{other_user.id}"
      }
    end
    
    {
      conversations: conversations,
      unread_count: @user.received_messages.unread.count,
      total_conversations: conversations.length,
      last_updated: Time.current
    }
  end
  
  def get_learning_insights_data(widget)
    # This would integrate with the existing learning insights system
    insights = @user.learning_insights.recent.limit(5)
    
    {
      insights: insights.map do |insight|
        {
          id: insight.id,
          title: insight.title,
          category: insight.category,
          priority: insight.priority,
          description: insight.description&.truncate(100),
          created_at: insight.created_at,
          url: "/learning_insights/#{insight.id}"
        }
      end,
      total_count: @user.learning_insights.count,
      high_priority_count: @user.learning_insights.where(priority: 'high').count,
      last_updated: Time.current
    }
  end
  
  def get_quick_actions_data(widget)
    config = widget.configuration_with_defaults
    actions = config['actions'] || ['new_note', 'new_assignment', 'calendar', 'messages']
    
    available_actions = {
      'new_note' => {
        title: 'New Note',
        icon: 'plus-circle',
        url: '/notes/new',
        color: 'blue'
      },
      'new_assignment' => {
        title: 'New Assignment',
        icon: 'academic-cap',
        url: '/assignments/new',
        color: 'green'
      },
      'calendar' => {
        title: 'Calendar',
        icon: 'calendar',
        url: '/schedules',
        color: 'purple'
      },
      'messages' => {
        title: 'Messages',
        icon: 'chat-bubble',
        url: '/messages/conversations',
        color: 'orange'
      },
      'search' => {
        title: 'Search',
        icon: 'search',
        url: '/search',
        color: 'gray'
      },
      'insights' => {
        title: 'Insights',
        icon: 'lightbulb',
        url: '/learning_insights',
        color: 'yellow'
      }
    }
    
    {
      actions: actions.map { |action| available_actions[action] }.compact,
      last_updated: Time.current
    }
  end
  
  # Placeholder methods for other widget types
  def get_calendar_preview_data(widget)
    { events: [], last_updated: Time.current }
  end
  
  def get_grade_overview_data(widget)
    { grades: [], average: 0, last_updated: Time.current }
  end
  
  def get_discussion_feed_data(widget)
    { discussions: [], last_updated: Time.current }
  end
  
  def get_weather_data(widget)
    { weather: { temperature: 22, condition: 'sunny' }, last_updated: Time.current }
  end
  
  # Helper methods
  def calculate_study_streak
    # This would calculate based on user activity
    # For now, return a random number between 1-30
    rand(1..30)
  end
  
  def calculate_deadline_priority(due_date)
    days_until = (due_date.to_date - Date.current).to_i
    case days_until
    when 0..1 then 'high'
    when 2..3 then 'medium'
    else 'low'
    end
  end
  
  def get_cached_widget_data(widget)
    # In a production app, you'd use Redis or Rails cache
    # For now, just return empty data to trigger refresh
    nil
  end
  
  def cache_widget_data(widget, data)
    # In production, cache the data with the widget ID as key
    Rails.logger.info "Caching data for widget #{widget.id}"
  end

  def get_ai_recommendations_data(widget)
    # Use cached recommendations or generate new ones
    cache_key = "ai_recommendations_#{@user.id}"
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      begin
        ai_service = AiRecommendationService.new(@user)
        recommendations = ai_service.generate_recommendations
        
        {
          recommendations: recommendations,
          widget_suggestions: ai_service.generate_widget_recommendations,
          generated_at: Time.current
        }
      rescue => e
        Rails.logger.error "Failed to generate AI recommendations: #{e.message}"
        
        # Fallback data
        {
          recommendations: {
            study_recommendations: [
              {
                type: 'general',
                title: 'Stay Consistent',
                description: 'Maintain regular study sessions for better retention.',
                priority: 'medium',
                action_url: '/study-planner',
                icon: 'fas fa-calendar-check'
              }
            ],
            content_suggestions: [],
            productivity_tips: [
              {
                type: 'time_management',
                title: 'Use Time Blocks',
                description: 'Divide your day into focused time blocks for different subjects.',
                priority: 'low',
                action_url: '/time-management',
                icon: 'fas fa-clock'
              }
            ]
          },
          widget_suggestions: [],
          generated_at: Time.current,
          error: 'Recommendations temporarily unavailable'
        }
      end
    end
  end

  # Static method for backward compatibility
  def self.ai_recommendations_data(user)
    service = new(user)
    widget = OpenStruct.new(widget_type: 'ai_recommendations', configuration: {})
    service.get_ai_recommendations_data(widget)
  end
end