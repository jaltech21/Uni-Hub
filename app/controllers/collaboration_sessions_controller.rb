class CollaborationSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: [:show, :join, :leave, :destroy, :pause, :resume]
  before_action :set_content, only: [:create, :show, :join]
  
  # GET /collaboration_sessions
  def index
    @active_sessions = current_user.collaborative_sessions
                                  .active
                                  .includes(:collaboratable, :session_participants)
                                  .order(started_at: :desc)
    
    @recent_sessions = current_user.session_participants
                                  .joins(:collaborative_session)
                                  .includes(collaborative_session: [:collaboratable, :created_by])
                                  .where(collaborative_sessions: { status: 'ended' })
                                  .order('collaborative_sessions.ended_at DESC')
                                  .limit(10)
                                  .map(&:collaborative_session)
  end
  
  # GET /collaboration_sessions/:id
  def show
    unless @session.can_join?(current_user)
      redirect_to collaboration_sessions_path, alert: 'You do not have permission to join this session.'
      return
    end
    
    @participant = @session.session_participants.find_by(user: current_user)
    @content = @session.collaboratable
    
    # Mark participant as active if they're already in the session
    @participant&.update_last_seen!
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          session: session_json(@session),
          participant: participant_json(@participant),
          content: content_json(@content),
          permissions: session_permissions(@session, current_user)
        }
      end
    end
  end
  
  # POST /assignments/:assignment_id/collaborate
  # POST /notes/:note_id/collaborate
  # POST /quizzes/:quiz_id/collaborate
  def create
    # Check if there's already an active session for this content
    existing_session = CollaborativeSession.active
                                          .where(collaboratable: @content)
                                          .first
    
    if existing_session && existing_session.can_join?(current_user)
      redirect_to collaboration_session_path(existing_session)
      return
    end
    
    @session = CollaborativeSession.new(session_params)
    @session.collaboratable = @content
    @session.created_by = current_user
    @session.session_token = generate_session_token
    
    if @session.save
      # Add creator as admin participant
      @session.add_participant(current_user, permission: 'admin')
      
      # Create initial version snapshot
      @session.create_initial_snapshot
      
      # Log session creation
      Rails.logger.info "Collaboration session #{@session.id} created for #{@content.class.name} #{@content.id}"
      
      redirect_to @session, notice: 'Collaboration session started successfully.'
    else
      redirect_back(fallback_location: @content, alert: 'Failed to start collaboration session.')
    end
  end
  
  # POST /collaboration_sessions/:id/join
  def join
    if @session.can_join?(current_user)
      participant = @session.add_participant(current_user)
      
      if participant
        # Log successful join
        Rails.logger.info "User #{current_user.id} joined collaboration session #{@session.id}"
        
        redirect_to @session, notice: 'Successfully joined the collaboration session.'
      else
        redirect_to collaboration_sessions_path, alert: 'Failed to join the session.'
      end
    else
      redirect_to collaboration_sessions_path, alert: 'You do not have permission to join this session.'
    end
  end
  
  # DELETE /collaboration_sessions/:id/leave
  def leave
    participant = @session.session_participants.find_by(user: current_user)
    
    if participant
      @session.remove_participant(current_user)
      Rails.logger.info "User #{current_user.id} left collaboration session #{@session.id}"
      
      redirect_to collaboration_sessions_path, notice: 'You have left the collaboration session.'
    else
      redirect_to collaboration_sessions_path, alert: 'You are not a participant in this session.'
    end
  end
  
  # PATCH /collaboration_sessions/:id/pause
  def pause
    unless @session.user_permission(current_user) == 'admin'
      render json: { error: 'Insufficient permissions' }, status: :forbidden
      return
    end
    
    if @session.update(status: 'paused')
      # Broadcast session paused
      ActionCable.server.broadcast(
        "collaboration_session_#{@session.session_token}",
        {
          type: 'session_paused',
          paused_by: current_user.id,
          timestamp: Time.current
        }
      )
      
      render json: { status: 'paused', message: 'Session paused successfully' }
    else
      render json: { error: 'Failed to pause session' }, status: :unprocessable_entity
    end
  end
  
  # PATCH /collaboration_sessions/:id/resume
  def resume
    unless @session.user_permission(current_user) == 'admin'
      render json: { error: 'Insufficient permissions' }, status: :forbidden
      return
    end
    
    if @session.update(status: 'active')
      # Broadcast session resumed
      ActionCable.server.broadcast(
        "collaboration_session_#{@session.session_token}",
        {
          type: 'session_resumed',
          resumed_by: current_user.id,
          timestamp: Time.current
        }
      )
      
      render json: { status: 'active', message: 'Session resumed successfully' }
    else
      render json: { error: 'Failed to resume session' }, status: :unprocessable_entity
    end
  end
  
  # DELETE /collaboration_sessions/:id
  def destroy
    unless @session.user_permission(current_user) == 'admin'
      redirect_to @session, alert: 'You do not have permission to end this session.'
      return
    end
    
    if @session.end_session!
      # Broadcast session ended
      ActionCable.server.broadcast(
        "collaboration_session_#{@session.session_token}",
        {
          type: 'session_ended',
          ended_by: current_user.id,
          timestamp: Time.current,
          final_metrics: @session.session_metrics
        }
      )
      
      Rails.logger.info "Collaboration session #{@session.id} ended by user #{current_user.id}"
      
      redirect_to collaboration_sessions_path, notice: 'Collaboration session ended successfully.'
    else
      redirect_to @session, alert: 'Failed to end the session.'
    end
  end
  
  # GET /collaboration_sessions/:id/participants
  def participants
    @session = CollaborativeSession.find(params[:id])
    
    unless @session.can_view?(current_user)
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return
    end
    
    participants = @session.active_participants.includes(:user).map do |participant|
      participant_json(participant)
    end
    
    render json: { participants: participants }
  end
  
  # GET /collaboration_sessions/:id/history
  def history
    @session = CollaborativeSession.find(params[:id])
    
    unless @session.can_view?(current_user)
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return
    end
    
    # Get session events and operations
    events = @session.collaboration_events
                    .includes(:user)
                    .order(event_timestamp: :desc)
                    .limit(50)
    
    operations = @session.edit_operations
                        .includes(:user)
                        .order(timestamp: :desc)
                        .limit(100)
    
    render json: {
      events: events.map { |event| event_json(event) },
      operations: operations.map { |op| operation_json(op) },
      session_metrics: @session.session_metrics
    }
  end
  
  # POST /collaboration_sessions/:id/invite
  def invite
    @session = CollaborativeSession.find(params[:id])
    
    unless @session.user_permission(current_user) == 'admin'
      render json: { error: 'Insufficient permissions' }, status: :forbidden
      return
    end
    
    user_ids = params[:user_ids] || []
    permission = params[:permission] || 'editor'
    
    invited_users = []
    errors = []
    
    user_ids.each do |user_id|
      user = User.find_by(id: user_id)
      
      if user.nil?
        errors << "User with ID #{user_id} not found"
        next
      end
      
      if @session.session_participants.exists?(user: user)
        errors << "#{user.name} is already a participant"
        next
      end
      
      participant = @session.add_participant(user, permission: permission)
      
      if participant
        invited_users << user
        
        # Send notification (implement your notification system)
        # NotificationService.send_collaboration_invite(user, @session, current_user)
      else
        errors << "Failed to invite #{user.name}"
      end
    end
    
    render json: {
      invited_users: invited_users.map { |u| { id: u.id, name: u.name } },
      errors: errors
    }
  end
  
  # PATCH /collaboration_sessions/:id/participants/:user_id
  def update_participant
    @session = CollaborativeSession.find(params[:id])
    participant = @session.session_participants.find_by(user_id: params[:user_id])
    
    unless @session.user_permission(current_user) == 'admin'
      render json: { error: 'Insufficient permissions' }, status: :forbidden
      return
    end
    
    unless participant
      render json: { error: 'Participant not found' }, status: :not_found
      return
    end
    
    if participant.update(participant_params)
      # Broadcast permission change
      ActionCable.server.broadcast(
        "collaboration_session_#{@session.session_token}",
        {
          type: 'permission_changed',
          participant_id: participant.user_id,
          new_permission: participant.permission_level,
          changed_by: current_user.id,
          timestamp: Time.current
        }
      )
      
      render json: participant_json(participant)
    else
      render json: { error: participant.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # DELETE /collaboration_sessions/:id/participants/:user_id
  def remove_participant
    @session = CollaborativeSession.find(params[:id])
    participant = @session.session_participants.find_by(user_id: params[:user_id])
    
    unless @session.user_permission(current_user) == 'admin'
      render json: { error: 'Insufficient permissions' }, status: :forbidden
      return
    end
    
    unless participant
      render json: { error: 'Participant not found' }, status: :not_found
      return
    end
    
    if participant.user == current_user
      render json: { error: 'Cannot remove yourself from the session' }, status: :unprocessable_entity
      return
    end
    
    reason = params[:reason] || 'Removed by admin'
    
    if participant.kick_from_session!(current_user, reason)
      # Broadcast participant removal
      ActionCable.server.broadcast(
        "collaboration_session_#{@session.session_token}",
        {
          type: 'participant_kicked',
          participant_id: participant.user_id,
          kicked_by: current_user.id,
          reason: reason,
          timestamp: Time.current
        }
      )
      
      render json: { message: 'Participant removed successfully' }
    else
      render json: { error: 'Failed to remove participant' }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_session
    @session = CollaborativeSession.find(params[:id])
  end
  
  def set_content
    if params[:assignment_id]
      @content = Assignment.find(params[:assignment_id])
    elsif params[:note_id]
      @content = Note.find(params[:note_id])
    elsif params[:quiz_id]
      @content = Quiz.find(params[:quiz_id])
    else
      redirect_back(fallback_location: root_path, alert: 'Invalid content type.')
    end
  end
  
  def session_params
    params.require(:collaborative_session).permit(
      :session_name, :max_participants, :session_settings
    )
  end
  
  def participant_params
    params.require(:participant).permit(:permission_level)
  end
  
  def generate_session_token
    SecureRandom.urlsafe_base64(32)
  end
  
  def session_json(session)
    {
      id: session.id,
      token: session.session_token,
      name: session.session_name,
      status: session.status,
      max_participants: session.max_participants,
      content_type: session.collaboratable_type,
      content_id: session.collaboratable_id,
      created_by: {
        id: session.created_by.id,
        name: session.created_by.name
      },
      started_at: session.started_at,
      participant_count: session.active_participants.count,
      settings: session.session_settings
    }
  end
  
  def participant_json(participant)
    return nil unless participant
    
    {
      id: participant.id,
      user_id: participant.user_id,
      user_name: participant.user.name,
      user_avatar: participant.user.avatar.attached? ? participant.user.avatar.url : nil,
      permission: participant.permission_level,
      joined_at: participant.joined_at,
      last_seen: participant.last_seen_at,
      online: participant.online?,
      edit_count: participant.edits_count,
      comment_count: participant.comments_count
    }
  end
  
  def content_json(content)
    {
      id: content.id,
      type: content.class.name,
      title: content.respond_to?(:title) ? content.title : content.name,
      content: content.content,
      updated_at: content.updated_at
    }
  end
  
  def session_permissions(session, user)
    permission = session.user_permission(user)
    
    {
      can_edit: %w[admin editor].include?(permission),
      can_comment: %w[admin editor viewer].include?(permission),
      can_invite: permission == 'admin',
      can_manage: permission == 'admin',
      level: permission
    }
  end
  
  def event_json(event)
    {
      id: event.id,
      type: event.event_type,
      data: event.event_data,
      user: {
        id: event.user.id,
        name: event.user.name
      },
      timestamp: event.event_timestamp
    }
  end
  
  def operation_json(operation)
    {
      id: operation.id,
      type: operation.operation_type,
      data: operation.operation_data,
      status: operation.status,
      user: {
        id: operation.user.id,
        name: operation.user.name
      },
      timestamp: operation.timestamp,
      sequence: operation.sequence_number
    }
  end
end