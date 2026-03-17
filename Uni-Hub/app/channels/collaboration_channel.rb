class CollaborationChannel < ApplicationCable::Channel
  def subscribed
    session_token = params[:session_token]
    @current_user = find_verified_user
    
    return reject unless @current_user
    return reject unless session_token.present?
    
    @session = CollaborativeSession.find_by(session_token: session_token)
    return reject unless @session
    return reject unless @session.can_join?(@current_user)
    
    # Join the session
    @participant = @session.add_participant(@current_user)
    return reject unless @participant
    
    # Subscribe to the session channel
    stream_from "collaboration_session_#{session_token}"
    
    # Send initial session state
    transmit({
      type: 'session_joined',
      session: session_info,
      participant: participant_info,
      active_participants: active_participants_info,
      current_cursors: current_cursors_info
    })
    
    # Broadcast that user joined
    broadcast_to_session({
      type: 'participant_joined',
      participant: participant_info
    })
    
    Rails.logger.info "User #{@current_user.id} joined collaboration session #{@session.id}"
  end
  
  def unsubscribed
    if @session && @participant
      @session.remove_participant(@current_user)
      
      # Broadcast that user left
      broadcast_to_session({
        type: 'participant_left',
        participant_id: @current_user.id,
        left_at: Time.current
      })
      
      Rails.logger.info "User #{@current_user.id} left collaboration session #{@session.id}"
    end
  end
  
  # Handle cursor position updates
  def update_cursor(data)
    return unless authenticated_and_active?
    
    position_data = data['position']
    return unless position_data.present?
    
    cursor = @session.update_cursor_position(@current_user, position_data)
    
    if cursor
      # Broadcast to other participants (not self)
      broadcast_to_others({
        type: 'cursor_update',
        user_id: @current_user.id,
        position: cursor.position_info
      })
    end
  end
  
  # Handle typing indicators
  def typing_start(data)
    return unless authenticated_and_active?
    
    cursor = @session.cursor_positions.find_by(user: @current_user)
    cursor&.start_typing!
    
    broadcast_to_others({
      type: 'typing_start',
      user_id: @current_user.id,
      content_path: data['content_path']
    })
  end
  
  def typing_stop(data)
    return unless authenticated_and_active?
    
    cursor = @session.cursor_positions.find_by(user: @current_user)
    cursor&.stop_typing!
    
    broadcast_to_others({
      type: 'typing_stop',
      user_id: @current_user.id
    })
  end
  
  # Handle edit operations
  def edit_operation(data)
    return unless authenticated_and_active?
    return unless @session.can_edit?(@current_user)
    
    operation_data = data['operation']
    return unless operation_data.present?
    
    # Create and apply the edit operation
    operation = @session.apply_edit_operation(@current_user, operation_data)
    
    if operation && operation.persisted?
      # Operation was successfully applied, broadcast to others
      broadcast_to_others({
        type: 'edit_operation',
        operation: {
          id: operation.id,
          user_id: @current_user.id,
          type: operation.operation_type,
          data: operation.transformed_data || operation.operation_data,
          sequence: operation.sequence_number,
          timestamp: operation.timestamp
        }
      })
      
      # Send acknowledgment to sender
      transmit({
        type: 'operation_acknowledged',
        operation_id: operation.operation_id,
        sequence: operation.sequence_number,
        status: operation.status
      })
    else
      # Operation failed, send error
      transmit({
        type: 'operation_error',
        operation_id: operation_data['operation_id'],
        error: 'Failed to apply operation'
      })
    end
  end
  
  # Handle comments
  def add_comment(data)
    return unless authenticated_and_active?
    return unless @session.can_comment?(@current_user)
    
    comment_data = data['comment']
    return unless comment_data.present?
    
    # Create collaboration event for comment
    event = @session.collaboration_events.create!(
      user: @current_user,
      event_type: 'comment',
      event_data: {
        content: comment_data['content'],
        position: comment_data['position'],
        content_path: comment_data['content_path']
      },
      event_timestamp: Time.current
    )
    
    if event.persisted?
      # Update participant comment count
      @participant.increment!(:comments_count)
      
      # Broadcast comment to all participants
      broadcast_to_session({
        type: 'comment_added',
        comment: {
          id: event.id,
          user_id: @current_user.id,
          user_name: @current_user.name,
          content: comment_data['content'],
          position: comment_data['position'],
          content_path: comment_data['content_path'],
          timestamp: event.event_timestamp
        }
      })
    end
  end
  
  # Handle conflict resolution
  def resolve_conflict(data)
    return unless authenticated_and_active?
    return unless @session.can_edit?(@current_user)
    
    operation_id = data['operation_id']
    resolution_strategy = data['resolution_strategy'] || 'manual'
    
    operation = @session.edit_operations.find_by(id: operation_id)
    return unless operation&.conflicted?
    
    if operation.resolve_conflict!(resolution_strategy, @current_user)
      broadcast_to_session({
        type: 'conflict_resolved',
        operation_id: operation.id,
        resolved_by: @current_user.id,
        resolution_strategy: resolution_strategy,
        timestamp: Time.current
      })
    end
  end
  
  # Handle session control (admin actions)
  def session_control(data)
    return unless authenticated_and_active?
    return unless @session.user_permission(@current_user) == 'admin'
    
    action = data['action']
    
    case action
    when 'pause_session'
      pause_session
    when 'resume_session'
      resume_session
    when 'end_session'
      end_session
    when 'kick_participant'
      kick_participant(data['participant_id'], data['reason'])
    when 'change_permissions'
      change_participant_permissions(data['participant_id'], data['new_permission'])
    end
  end
  
  # Request session snapshot
  def request_snapshot(data)
    return unless authenticated_and_active?
    
    snapshot = @session.create_snapshot
    
    transmit({
      type: 'snapshot_created',
      snapshot: snapshot,
      timestamp: Time.current
    })
  end
  
  # Heartbeat to maintain connection
  def heartbeat(data)
    return unless authenticated_and_active?
    
    @participant.update_last_seen!
    
    transmit({
      type: 'heartbeat_acknowledged',
      timestamp: Time.current,
      session_active: @session.active?
    })
  end
  
  private
  
  def authenticated_and_active?
    @current_user && @session&.active? && @participant&.active?
  end
  
  def find_verified_user
    # This should integrate with your authentication system
    # For now, assuming current_user is available
    current_user
  end
  
  def session_info
    {
      id: @session.id,
      token: @session.session_token,
      name: @session.session_name,
      status: @session.status,
      max_participants: @session.max_participants,
      content_type: @session.collaboratable_type,
      content_id: @session.collaboratable_id,
      created_by: @session.created_by.name,
      started_at: @session.started_at
    }
  end
  
  def participant_info
    {
      id: @participant.id,
      user_id: @current_user.id,
      user_name: @current_user.name,
      user_avatar: @current_user.avatar.attached? ? @current_user.avatar.url : nil,
      permission: @participant.permission_level,
      joined_at: @participant.joined_at,
      color: assign_user_color
    }
  end
  
  def active_participants_info
    @session.active_participants.includes(:user).map do |participant|
      {
        id: participant.id,
        user_id: participant.user_id,
        user_name: participant.user.name,
        user_avatar: participant.user.avatar.attached? ? participant.user.avatar.url : nil,
        permission: participant.permission_level,
        joined_at: participant.joined_at,
        last_seen: participant.last_seen_at,
        online: participant.online?
      }
    end
  end
  
  def current_cursors_info
    @session.cursor_positions.active_cursors.includes(:user).map do |cursor|
      cursor.position_info
    end
  end
  
  def assign_user_color
    cursor = @session.cursor_positions.find_or_create_by(user: @current_user)
    cursor.assign_user_color! unless cursor.user_color.present?
    cursor.user_color
  end
  
  def broadcast_to_session(data)
    ActionCable.server.broadcast("collaboration_session_#{@session.session_token}", data)
  end
  
  def broadcast_to_others(data)
    # Broadcast to all participants except the current user
    data[:exclude_user_id] = @current_user.id
    broadcast_to_session(data)
  end
  
  def pause_session
    if @session.update(status: 'paused')
      broadcast_to_session({
        type: 'session_paused',
        paused_by: @current_user.id,
        timestamp: Time.current
      })
    end
  end
  
  def resume_session
    if @session.update(status: 'active')
      broadcast_to_session({
        type: 'session_resumed',
        resumed_by: @current_user.id,
        timestamp: Time.current
      })
    end
  end
  
  def end_session
    if @session.end_session!
      broadcast_to_session({
        type: 'session_ended',
        ended_by: @current_user.id,
        timestamp: Time.current,
        final_metrics: @session.session_metrics
      })
    end
  end
  
  def kick_participant(participant_id, reason = nil)
    participant = @session.session_participants.find_by(user_id: participant_id)
    return unless participant && participant.user != @current_user
    
    if participant.kick_from_session!(@current_user, reason)
      broadcast_to_session({
        type: 'participant_kicked',
        participant_id: participant_id,
        kicked_by: @current_user.id,
        reason: reason,
        timestamp: Time.current
      })
    end
  end
  
  def change_participant_permissions(participant_id, new_permission)
    participant = @session.session_participants.find_by(user_id: participant_id)
    return unless participant && participant.user != @current_user
    
    if participant.promote_permission!(new_permission, @current_user)
      broadcast_to_session({
        type: 'permission_changed',
        participant_id: participant_id,
        new_permission: new_permission,
        changed_by: @current_user.id,
        timestamp: Time.current
      })
    end
  end
end