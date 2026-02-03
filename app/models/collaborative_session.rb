class CollaborativeSession < ApplicationRecord
  belongs_to :collaboratable, polymorphic: true
  belongs_to :created_by, class_name: 'User'
  
  has_many :session_participants, dependent: :destroy
  has_many :participants, through: :session_participants, source: :user
  has_many :collaboration_events, dependent: :destroy
  has_many :cursor_positions, dependent: :destroy
  has_many :edit_operations, dependent: :destroy
  
  # Validations
  validates :session_token, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active paused ended] }
  validates :max_participants, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  
  # Enums
  enum status: { active: 0, paused: 1, ended: 2 }
  enum permission_level: { view_only: 0, comment: 1, edit: 2, admin: 3 }
  
  # Scopes
  scope :active_sessions, -> { where(status: 'active') }
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_user, ->(user) { joins(:session_participants).where(session_participants: { user: user }) }
  
  # Callbacks
  before_create :generate_session_token
  after_create :add_creator_as_participant
  before_update :track_status_changes
  
  # Virtual attributes
  attr_accessor :current_user
  
  def add_participant(user, permission: 'edit')
    return false if participants.count >= max_participants
    return false if participants.include?(user)
    
    participant = session_participants.create!(
      user: user,
      permission_level: permission,
      joined_at: Time.current
    )
    
    broadcast_participant_joined(participant)
    participant
  end
  
  def remove_participant(user)
    participant = session_participants.find_by(user: user)
    return false unless participant
    
    participant.update!(left_at: Time.current, status: 'left')
    broadcast_participant_left(participant)
    
    # End session if no active participants remain
    end_session! if active_participants.empty?
    
    true
  end
  
  def active_participants
    session_participants.where(status: 'active')
  end
  
  def participant_count
    active_participants.count
  end
  
  def can_join?(user)
    return false unless active?
    return false if participants.count >= max_participants
    return true if participants.include?(user)
    
    # Check permissions based on collaboratable object
    case collaboratable
    when Assignment
      collaboratable.user == user || user.admin?
    when Note
      collaboratable.viewable_by?(user)
    when Quiz
      collaboratable.user == user || user.admin?
    else
      false
    end
  end
  
  def user_permission(user)
    participant = session_participants.find_by(user: user)
    participant&.permission_level || 'view_only'
  end
  
  def can_edit?(user)
    permission = user_permission(user)
    %w[edit admin].include?(permission)
  end
  
  def can_comment?(user)
    permission = user_permission(user)
    %w[comment edit admin].include?(permission)
  end
  
  def update_cursor_position(user, position_data)
    cursor = cursor_positions.find_or_initialize_by(user: user)
    cursor.assign_attributes(
      position_data: position_data,
      updated_at: Time.current
    )
    
    if cursor.save
      broadcast_cursor_update(cursor)
      cursor
    else
      false
    end
  end
  
  def apply_edit_operation(user, operation_data)
    return false unless can_edit?(user)
    
    operation = edit_operations.build(
      user: user,
      operation_type: operation_data[:type],
      operation_data: operation_data,
      sequence_number: next_sequence_number,
      timestamp: Time.current
    )
    
    if operation.save
      # Apply operational transformation if needed
      transformed_operation = transform_operation(operation)
      
      # Broadcast to other participants
      broadcast_edit_operation(transformed_operation)
      
      # Update content optimistically
      apply_operation_to_content(transformed_operation)
      
      operation
    else
      false
    end
  end
  
  def resolve_conflict(operations, resolution_strategy = 'last_writer_wins')
    resolver = ConflictResolver.new(self, operations, resolution_strategy)
    resolver.resolve
  end
  
  def create_snapshot
    snapshot_data = {
      content: extract_current_content,
      participants: active_participants.map(&:user_snapshot),
      timestamp: Time.current,
      version: current_version_number
    }
    
    update!(
      snapshot_data: snapshot_data,
      last_snapshot_at: Time.current
    )
    
    snapshot_data
  end
  
  def restore_from_snapshot(snapshot_timestamp = nil)
    target_snapshot = snapshot_timestamp ? 
      find_snapshot_at(snapshot_timestamp) : 
      snapshot_data
    
    return false unless target_snapshot
    
    # Restore content
    restore_content_from_snapshot(target_snapshot)
    
    # Create restoration event
    collaboration_events.create!(
      event_type: 'snapshot_restored',
      user: current_user,
      event_data: {
        restored_from: snapshot_timestamp || last_snapshot_at,
        restored_at: Time.current
      }
    )
    
    true
  end
  
  def end_session!
    return false unless active?
    
    transaction do
      # Create final snapshot
      create_snapshot
      
      # Update all active participants
      active_participants.update_all(
        left_at: Time.current,
        status: 'left'
      )
      
      # Update session status
      update!(
        status: 'ended',
        ended_at: Time.current
      )
      
      # Broadcast session ended
      broadcast_session_ended
      
      # Clean up real-time data
      cleanup_realtime_data
    end
    
    true
  end
  
  def session_metrics
    {
      duration: session_duration,
      total_participants: session_participants.count,
      peak_concurrent_users: calculate_peak_concurrent_users,
      total_edits: edit_operations.count,
      total_comments: collaboration_events.where(event_type: 'comment').count,
      conflict_count: collaboration_events.where(event_type: 'conflict_resolved').count
    }
  end
  
  def activity_timeline(limit: 50)
    events = collaboration_events
             .includes(:user)
             .order(created_at: :desc)
             .limit(limit)
    
    events.map do |event|
      {
        id: event.id,
        type: event.event_type,
        user: {
          id: event.user.id,
          name: event.user.name,
          avatar_url: event.user.avatar.attached? ? event.user.avatar.url : nil
        },
        timestamp: event.created_at,
        data: event.event_data
      }
    end
  end
  
  private
  
  def generate_session_token
    self.session_token = SecureRandom.hex(16)
  end
  
  def add_creator_as_participant
    session_participants.create!(
      user: created_by,
      permission_level: 'admin',
      joined_at: Time.current,
      status: 'active'
    )
  end
  
  def track_status_changes
    if status_changed? && status_was == 'active'
      collaboration_events.create!(
        event_type: 'status_changed',
        user: current_user || created_by,
        event_data: {
          from: status_was,
          to: status,
          changed_at: Time.current
        }
      )
    end
  end
  
  def broadcast_participant_joined(participant)
    ActionCable.server.broadcast(
      "collaboration_session_#{session_token}",
      {
        type: 'participant_joined',
        participant: {
          id: participant.user.id,
          name: participant.user.name,
          permission: participant.permission_level,
          joined_at: participant.joined_at
        }
      }
    )
  end
  
  def broadcast_participant_left(participant)
    ActionCable.server.broadcast(
      "collaboration_session_#{session_token}",
      {
        type: 'participant_left',
        participant_id: participant.user.id,
        left_at: participant.left_at
      }
    )
  end
  
  def broadcast_cursor_update(cursor)
    ActionCable.server.broadcast(
      "collaboration_session_#{session_token}",
      {
        type: 'cursor_update',
        user_id: cursor.user.id,
        position: cursor.position_data,
        timestamp: cursor.updated_at
      }
    )
  end
  
  def broadcast_edit_operation(operation)
    ActionCable.server.broadcast(
      "collaboration_session_#{session_token}",
      {
        type: 'edit_operation',
        operation: {
          id: operation.id,
          user_id: operation.user.id,
          type: operation.operation_type,
          data: operation.operation_data,
          sequence: operation.sequence_number,
          timestamp: operation.timestamp
        }
      }
    )
  end
  
  def broadcast_session_ended
    ActionCable.server.broadcast(
      "collaboration_session_#{session_token}",
      {
        type: 'session_ended',
        ended_at: ended_at,
        final_metrics: session_metrics
      }
    )
  end
  
  def next_sequence_number
    (edit_operations.maximum(:sequence_number) || 0) + 1
  end
  
  def current_version_number
    collaboratable.respond_to?(:latest_version) ? 
      collaboratable.latest_version&.version_number || 1 : 1
  end
  
  def transform_operation(operation)
    # Implement Operational Transformation (OT) logic
    # This is a simplified version - real OT is quite complex
    OperationalTransformer.new(self).transform(operation)
  end
  
  def apply_operation_to_content(operation)
    # Apply the operation to the actual content
    case operation.operation_type
    when 'insert'
      apply_insert_operation(operation)
    when 'delete'
      apply_delete_operation(operation)
    when 'format'
      apply_format_operation(operation)
    end
  end
  
  def apply_insert_operation(operation)
    # Implementation depends on the content type
    ContentOperationApplier.new(collaboratable).apply_insert(operation)
  end
  
  def apply_delete_operation(operation)
    ContentOperationApplier.new(collaboratable).apply_delete(operation)
  end
  
  def apply_format_operation(operation)
    ContentOperationApplier.new(collaboratable).apply_format(operation)
  end
  
  def extract_current_content
    case collaboratable
    when Assignment
      {
        title: collaboratable.title,
        description: collaboratable.description,
        instructions: collaboratable.instructions
      }
    when Note
      {
        title: collaboratable.title,
        content: collaboratable.content
      }
    when Quiz
      {
        title: collaboratable.title,
        description: collaboratable.description,
        questions: collaboratable.quiz_questions.as_json
      }
    else
      {}
    end
  end
  
  def restore_content_from_snapshot(snapshot)
    content = snapshot['content']
    
    collaboratable.class.without_versioning do
      case collaboratable
      when Assignment
        collaboratable.update!(
          title: content['title'],
          description: content['description'],
          instructions: content['instructions']
        )
      when Note
        collaboratable.update!(
          title: content['title'],
          content: content['content']
        )
      when Quiz
        collaboratable.update!(
          title: content['title'],
          description: content['description']
        )
        # Handle questions restoration separately
      end
    end
  end
  
  def find_snapshot_at(timestamp)
    # Find snapshot closest to the given timestamp
    # This would query a snapshots table or stored snapshots
    nil # Placeholder
  end
  
  def session_duration
    return 0 unless created_at
    
    end_time = ended_at || Time.current
    ((end_time - created_at) / 1.minute).round(2)
  end
  
  def calculate_peak_concurrent_users
    # This would require more complex tracking of participant join/leave times
    # For now, return the maximum participants we've seen
    session_participants.count
  end
  
  def cleanup_realtime_data
    # Clean up temporary real-time data
    cursor_positions.delete_all
    
    # Archive old edit operations (keep recent ones for conflict resolution)
    old_operations = edit_operations.where('created_at < ?', 1.hour.ago)
    old_operations.delete_all
  end
end