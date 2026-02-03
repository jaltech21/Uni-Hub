module CollaborationHelper
  # Generate consistent colors for participants
  def participant_color(user_id)
    colors = [
      '#3B82F6', '#EF4444', '#10B981', '#F59E0B', 
      '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16',
      '#F97316', '#6366F1', '#14B8A6', '#EAB308',
      '#A855F7', '#EC4899', '#0EA5E9', '#65A30D'
    ]
    colors[user_id % colors.length]
  end
  
  # Format collaboration status
  def collaboration_status_badge(status)
    case status
    when 'active'
      content_tag :span, 'Active', class: 'badge bg-success'
    when 'paused'
      content_tag :span, 'Paused', class: 'badge bg-warning'
    when 'ended'
      content_tag :span, 'Ended', class: 'badge bg-secondary'
    else
      content_tag :span, status.humanize, class: 'badge bg-light text-dark'
    end
  end
  
  # Format permission level
  def permission_badge(permission)
    case permission
    when 'admin'
      content_tag :span, 'Admin', class: 'badge bg-danger'
    when 'editor'
      content_tag :span, 'Editor', class: 'badge bg-primary'
    when 'viewer'
      content_tag :span, 'Viewer', class: 'badge bg-secondary'
    else
      content_tag :span, permission.humanize, class: 'badge bg-light text-dark'
    end
  end
  
  # Check if user can start collaboration
  def can_collaborate?(content, user)
    case content
    when Assignment
      content.user == user || user.can_access_department?(content.department)
    when Note
      content.user == user || content.shared_with_user?(user)
    when Quiz
      content.user == user || user.can_access_department?(content.department)
    else
      false
    end
  end
  
  # Get collaboration button for content
  def collaboration_button(content, user, options = {})
    return unless can_collaborate?(content, user)
    
    # Check for existing active session
    existing_session = CollaborativeSession.active
                                          .where(collaboratable: content)
                                          .first
    
    if existing_session && existing_session.can_join?(user)
      link_to 'Join Collaboration', 
              collaboration_session_path(existing_session),
              class: "btn btn-success #{options[:class]}",
              data: { 
                turbo_confirm: 'Join the existing collaboration session?',
                bs_toggle: 'tooltip',
                bs_title: "#{existing_session.active_participants.count} participants active"
              }
    else
      button_to 'Start Collaboration',
                polymorphic_path([content, :collaborate]),
                method: :post,
                class: "btn btn-primary #{options[:class]}",
                form: { data: { turbo_confirm: 'Start a new collaboration session?' } },
                params: { 
                  collaborative_session: { 
                    session_name: "#{content.class.name}: #{content.respond_to?(:title) ? content.title : content.name}",
                    max_participants: 10
                  }
                }
    end
  end
  
  # Format session duration
  def session_duration(session)
    if session.ended_at
      distance_of_time_in_words(session.started_at, session.ended_at)
    else
      "#{distance_of_time_in_words(session.started_at, Time.current)} (ongoing)"
    end
  end
  
  # Get session metrics summary
  def session_metrics_summary(session)
    metrics = session.session_metrics
    
    content_tag :div, class: 'session-metrics d-flex gap-3' do
      [
        content_tag(:div, class: 'metric') do
          content_tag(:div, metrics[:total_edits], class: 'metric-value') +
          content_tag(:div, 'Edits', class: 'metric-label')
        end,
        content_tag(:div, class: 'metric') do
          content_tag(:div, metrics[:total_comments], class: 'metric-value') +
          content_tag(:div, 'Comments', class: 'metric-label')
        end,
        content_tag(:div, class: 'metric') do
          content_tag(:div, metrics[:unique_editors], class: 'metric-value') +
          content_tag(:div, 'Editors', class: 'metric-label')
        end
      ].join.html_safe
    end
  end
  
  # Participant avatar
  def participant_avatar(user, size = 'small', show_online = false)
    size_class = case size
                when 'tiny' then 'participant-avatar-tiny'
                when 'small' then 'participant-avatar-small'
                when 'medium' then 'participant-avatar-medium'
                when 'large' then 'participant-avatar-large'
                else 'participant-avatar-small'
                end
    
    content_tag :div, class: "#{size_class} position-relative", 
                style: "background-color: #{participant_color(user.id)}" do
      avatar_content = if user.avatar.attached?
                        image_tag user.avatar, alt: user.name, class: "w-100 h-100 rounded-circle"
                      else
                        user.name.first.upcase
                      end
      
      online_indicator = if show_online
                          content_tag(:div, '', class: 'online-indicator')
                        else
                          ''
                        end
      
      (avatar_content + online_indicator).html_safe
    end
  end
  
  # Typing indicator
  def typing_indicator(users)
    return if users.empty?
    
    content_tag :div, class: 'typing-indicator' do
      user_names = users.map(&:name).join(', ')
      text = users.count == 1 ? "#{user_names} is typing..." : "#{user_names} are typing..."
      
      content_tag(:span, text, class: 'typing-text') +
      content_tag(:div, class: 'typing-dots') do
        3.times.map { content_tag(:span, '') }.join.html_safe
      end
    end
  end
  
  # Real-time status indicator
  def realtime_status_indicator(connected = true, quality = 'good')
    status_class = connected ? 'text-success' : 'text-danger'
    status_text = connected ? 'Connected' : 'Disconnected'
    
    content_tag :div, class: "realtime-status #{status_class}" do
      content_tag(:i, '', class: 'bi bi-circle-fill me-1') +
      content_tag(:span, status_text) +
      if connected
        content_tag(:div, class: 'connection-quality ms-2') do
          4.times.map.with_index do |_, i|
            active_class = case quality
                          when 'excellent' then i < 4 ? 'active' : ''
                          when 'good' then i < 3 ? 'active' : ''
                          when 'fair' then i < 2 ? 'active' : ''
                          when 'poor' then i < 1 ? 'active' : ''
                          else ''
                          end
            
            content_tag(:div, '', class: "connection-bar #{active_class}")
          end.join.html_safe
        end
      else
        ''
      end
    end
  end
  
  # Version comparison indicator
  def version_conflict_indicator(operation, show_details = false)
    return unless operation.conflicted?
    
    content_tag :div, class: 'version-conflict alert alert-warning' do
      icon = content_tag(:i, '', class: 'bi bi-exclamation-triangle me-2')
      text = 'Version conflict detected'
      
      if show_details
        details = content_tag(:div, class: 'conflict-details mt-2') do
          "Conflicting changes at position #{operation.operation_data['position']} " +
          "by #{operation.user.name} at #{operation.timestamp.strftime('%I:%M %p')}"
        end
        icon + text + details
      else
        icon + text
      end
    end
  end
  
  # Collaboration permissions check
  def can_edit_in_session?(session, user)
    permission = session.user_permission(user)
    %w[admin editor].include?(permission)
  end
  
  def can_comment_in_session?(session, user)
    permission = session.user_permission(user)
    %w[admin editor viewer].include?(permission)
  end
  
  def can_manage_session?(session, user)
    session.user_permission(user) == 'admin'
  end
  
  # Format operation for display
  def format_operation(operation)
    case operation.operation_type
    when 'insert'
      "Added \"#{truncate(operation.operation_data['content'], length: 50)}\""
    when 'delete'
      "Deleted #{operation.operation_data['length']} characters"
    when 'replace'
      "Replaced \"#{truncate(operation.operation_data['old_content'], length: 30)}\" with \"#{truncate(operation.operation_data['new_content'], length: 30)}\""
    when 'format'
      "Applied #{operation.operation_data['format_type']} formatting"
    else
      operation.operation_type.humanize
    end
  end
  
  # Session activity feed item
  def session_activity_item(event)
    content_tag :div, class: 'activity-item d-flex align-items-start' do
      avatar = participant_avatar(event.user, 'tiny')
      
      content = content_tag(:div, class: 'activity-content ms-2 flex-grow-1') do
        header = content_tag(:div, class: 'activity-header') do
          content_tag(:strong, event.user.name) +
          content_tag(:span, " #{event.event_type.humanize.downcase}", class: 'text-muted') +
          content_tag(:span, time_ago_in_words(event.event_timestamp), class: 'activity-time text-muted ms-2')
        end
        
        details = if event.event_data.present?
                   content_tag(:div, class: 'activity-details text-muted small') do
                     case event.event_type
                     when 'comment'
                       truncate(event.event_data['content'], length: 100)
                     when 'edit'
                       format_operation(event)
                     else
                       event.event_data.to_s
                     end
                   end
                 else
                   ''
                 end
        
        header + details
      end
      
      avatar + content
    end
  end
end