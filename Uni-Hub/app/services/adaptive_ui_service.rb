class AdaptiveUiService
  def initialize(user)
    @user = user
    @activity_service = UserActivityService.new(user)
  end

  def generate_ui_adaptations
    {
      navigation_shortcuts: generate_navigation_shortcuts,
      widget_suggestions: generate_widget_suggestions,
      layout_optimizations: generate_layout_optimizations,
      feature_recommendations: generate_feature_recommendations
    }
  end

  def apply_adaptive_changes
    adaptations = generate_ui_adaptations
    
    # Apply navigation shortcuts
    update_user_shortcuts(adaptations[:navigation_shortcuts])
    
    # Suggest widget additions/removals
    suggest_widget_changes(adaptations[:widget_suggestions])
    
    # Optimize layout based on usage
    optimize_dashboard_layout(adaptations[:layout_optimizations])
    
    adaptations
  end

  private

  def generate_navigation_shortcuts
    shortcuts = []
    most_used_features = @activity_service.most_used_features
    
    most_used_features.each do |feature|
      case feature
      when 'notes'
        shortcuts << {
          label: 'Quick Note',
          url: '/notes/new',
          icon: 'fas fa-plus',
          priority: 'high'
        }
      when 'calendar'
        shortcuts << {
          label: 'Today\'s Schedule',
          url: '/dashboard?focus=calendar',
          icon: 'fas fa-calendar-day',
          priority: 'high'
        }
      when 'assignments'
        shortcuts << {
          label: 'Due Soon',
          url: '/assignments?filter=due_soon',
          icon: 'fas fa-exclamation-triangle',
          priority: 'medium'
        }
      end
    end
    
    shortcuts
  end

  def generate_widget_suggestions
    suggestions = []
    usage_patterns = @activity_service.peak_usage_hours
    
    # Morning users benefit from daily planner
    if usage_patterns.include?('morning')
      suggestions << {
        action: 'add',
        widget_type: 'daily_planner',
        reason: 'Perfect for your morning routine',
        priority: 'medium'
      }
    end
    
    # Heavy assignment users need progress tracking
    if @user.assignments.active.count > 5
      suggestions << {
        action: 'add',
        widget_type: 'assignment_progress',
        reason: 'Track your multiple assignments',
        priority: 'high'
      }
    end
    
    # Social learners benefit from study groups
    if @activity_service.collaboration_frequency == 'high'
      suggestions << {
        action: 'add',
        widget_type: 'study_groups',
        reason: 'Stay connected with study partners',
        priority: 'medium'
      }
    end
    
    # Remove unused widgets
    unused_widgets = identify_unused_widgets
    unused_widgets.each do |widget|
      suggestions << {
        action: 'remove',
        widget_id: widget.id,
        widget_type: widget.widget_type,
        reason: 'Not used in the last 2 weeks',
        priority: 'low'
      }
    end
    
    suggestions
  end

  def generate_layout_optimizations
    optimizations = []
    current_layout = @user.dashboard_widgets.order(:position)
    
    # Suggest moving frequently used widgets to prominent positions
    frequently_used = current_layout.joins("LEFT JOIN user_widget_interactions uwi ON uwi.widget_id = user_dashboard_widgets.id")
                                   .where("uwi.last_interaction > ?", 1.week.ago)
                                   .group(:id)
                                   .order("COUNT(uwi.id) DESC")
                                   .limit(3)
    
    frequently_used.each_with_index do |widget, index|
      if widget.position > index
        optimizations << {
          type: 'reposition',
          widget_id: widget.id,
          current_position: widget.position,
          suggested_position: index,
          reason: 'Move frequently used widget to top'
        }
      end
    end
    
    # Suggest grouping related widgets
    related_groups = identify_related_widgets
    related_groups.each do |group|
      if widgets_are_scattered?(group[:widgets])
        optimizations << {
          type: 'group',
          widget_ids: group[:widgets].map(&:id),
          reason: "Group #{group[:type]} widgets together",
          suggested_area: calculate_optimal_grouping_area(group[:widgets])
        }
      end
    end
    
    optimizations
  end

  def generate_feature_recommendations
    recommendations = []
    feature_usage = analyze_feature_usage
    
    # Recommend underused but beneficial features
    if feature_usage[:calendar_usage] < 0.3 && @user.assignments.any?
      recommendations << {
        feature: 'calendar_integration',
        title: 'Sync Assignment Deadlines',
        description: 'Automatically add assignment due dates to your calendar',
        benefit: 'Never miss a deadline',
        action_url: '/settings/calendar',
        priority: 'high'
      }
    end
    
    if feature_usage[:study_groups_usage] < 0.2 && has_classmates?
      recommendations << {
        feature: 'study_groups',
        title: 'Join Study Groups',
        description: 'Connect with classmates for collaborative learning',
        benefit: 'Improve understanding through discussion',
        action_url: '/study-groups',
        priority: 'medium'
      }
    end
    
    if feature_usage[:note_sharing] < 0.1 && @user.notes.count > 10
      recommendations << {
        feature: 'note_sharing',
        title: 'Share Your Notes',
        description: 'Help classmates and get feedback on your notes',
        benefit: 'Build reputation and improve note quality',
        action_url: '/notes?action=share',
        priority: 'low'
      }
    end
    
    recommendations
  end

  def update_user_shortcuts(shortcuts)
    # Store user's adaptive shortcuts in preferences
    preferences = @user.personalization_preference || @user.build_personalization_preference
    
    current_shortcuts = preferences.ui_preferences['shortcuts'] || []
    new_shortcuts = shortcuts.select { |s| s[:priority] == 'high' }
    
    # Merge with existing shortcuts, avoiding duplicates
    merged_shortcuts = (current_shortcuts + new_shortcuts).uniq { |s| s[:url] }
    
    preferences.ui_preferences = preferences.ui_preferences.merge(
      'shortcuts' => merged_shortcuts.take(5) # Limit to 5 shortcuts
    )
    
    preferences.save if preferences.changed?
  end

  def suggest_widget_changes(suggestions)
    # Store widget suggestions for user review
    high_priority_suggestions = suggestions.select { |s| s[:priority] == 'high' }
    
    # Auto-apply some low-impact suggestions
    auto_apply_suggestions = suggestions.select do |s|
      s[:action] == 'remove' && s[:priority] == 'low'
    end
    
    auto_apply_suggestions.each do |suggestion|
      widget = @user.dashboard_widgets.find(suggestion[:widget_id])
      widget.update(hidden: true) if widget
    end
    
    # Log suggestions for user notification
    Rails.logger.info "Generated #{suggestions.count} widget suggestions for user #{@user.id}"
  end

  def optimize_dashboard_layout(optimizations)
    # Apply layout optimizations that don't require user approval
    auto_apply_optimizations = optimizations.select { |o| o[:type] == 'reposition' }
    
    auto_apply_optimizations.each do |optimization|
      widget = @user.dashboard_widgets.find(optimization[:widget_id])
      if widget && widget.position != optimization[:suggested_position]
        widget.update(position: optimization[:suggested_position])
      end
    end
  end

  def identify_unused_widgets
    # Find widgets that haven't been interacted with recently
    cutoff_date = 2.weeks.ago
    
    @user.dashboard_widgets.joins("LEFT JOIN user_widget_interactions uwi ON uwi.widget_id = user_dashboard_widgets.id")
         .where("uwi.last_interaction < ? OR uwi.last_interaction IS NULL", cutoff_date)
  end

  def identify_related_widgets
    groups = []
    
    # Academic widgets
    academic_widgets = @user.dashboard_widgets.where(
      widget_type: ['assignments', 'upcoming_deadlines', 'grade_overview', 'calendar']
    )
    if academic_widgets.count >= 2
      groups << { type: 'academic', widgets: academic_widgets }
    end
    
    # Productivity widgets
    productivity_widgets = @user.dashboard_widgets.where(
      widget_type: ['daily_planner', 'quick_stats', 'recent_activity']
    )
    if productivity_widgets.count >= 2
      groups << { type: 'productivity', widgets: productivity_widgets }
    end
    
    # Social widgets
    social_widgets = @user.dashboard_widgets.where(
      widget_type: ['study_groups', 'discussion_feed', 'notifications']
    )
    if social_widgets.count >= 2
      groups << { type: 'social', widgets: social_widgets }
    end
    
    groups
  end

  def widgets_are_scattered?(widgets)
    # Check if widgets are far apart in the layout
    positions = widgets.pluck(:grid_x, :grid_y)
    return false if positions.count < 2
    
    # Calculate distance between widgets
    max_distance = 0
    positions.each_with_index do |pos1, i|
      positions[(i+1)..-1].each do |pos2|
        distance = Math.sqrt((pos1[0] - pos2[0])**2 + (pos1[1] - pos2[1])**2)
        max_distance = [max_distance, distance].max
      end
    end
    
    max_distance > 3 # Widgets are scattered if max distance > 3 grid units
  end

  def calculate_optimal_grouping_area(widgets)
    # Calculate the best area to group related widgets
    current_positions = widgets.map { |w| [w.grid_x, w.grid_y] }
    
    # Find the centroid
    center_x = current_positions.sum { |pos| pos[0] } / current_positions.count
    center_y = current_positions.sum { |pos| pos[1] } / current_positions.count
    
    # Suggest grouping around the centroid
    {
      center_x: center_x.round,
      center_y: center_y.round,
      suggested_layout: arrange_widgets_in_group(widgets, center_x, center_y)
    }
  end

  def arrange_widgets_in_group(widgets, center_x, center_y)
    # Arrange widgets in a compact group around the center point
    arrangements = []
    
    widgets.each_with_index do |widget, index|
      # Create a 2x2 or 3x2 grid arrangement
      row = index / 2
      col = index % 2
      
      arrangements << {
        widget_id: widget.id,
        grid_x: center_x + col,
        grid_y: center_y + row
      }
    end
    
    arrangements
  end

  def analyze_feature_usage
    # Analyze how much user utilizes different features
    {
      calendar_usage: calculate_calendar_usage,
      study_groups_usage: calculate_study_groups_usage,
      note_sharing: calculate_note_sharing_usage,
      discussion_participation: calculate_discussion_participation
    }
  end

  def calculate_calendar_usage
    total_events = @user.calendar_events.where('created_at > ?', 1.month.ago).count
    potential_events = @user.assignments.count + @user.schedules.count
    
    return 0 if potential_events == 0
    [total_events.to_f / potential_events, 1.0].min
  end

  def calculate_study_groups_usage
    participations = @user.study_group_participations.where('created_at > ?', 1.month.ago).count
    available_groups = StudyGroup.joins(:course).where(courses: { id: @user.courses.pluck(:id) }).count
    
    return 0 if available_groups == 0
    [participations.to_f / available_groups, 1.0].min
  end

  def calculate_note_sharing_usage
    shared_notes = @user.notes.where.not(shared_with: nil).count
    total_notes = @user.notes.count
    
    return 0 if total_notes == 0
    shared_notes.to_f / total_notes
  end

  def calculate_discussion_participation
    posts = @user.discussion_posts.where('created_at > ?', 1.month.ago).count
    available_discussions = Discussion.joins(:course).where(courses: { id: @user.courses.pluck(:id) }).count
    
    return 0 if available_discussions == 0
    [posts.to_f / available_discussions, 1.0].min
  end

  def has_classmates?
    @user.courses.joins(:enrollments).where.not(enrollments: { user_id: @user.id }).exists?
  end
end