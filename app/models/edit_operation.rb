class EditOperation < ApplicationRecord
  belongs_to :collaborative_session
  belongs_to :user
  belongs_to :parent_operation, class_name: 'EditOperation', optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true
  
  has_many :child_operations, class_name: 'EditOperation', foreign_key: 'parent_operation_id'
  has_many :collaboration_events, foreign_key: 'related_operation_id'
  
  # Enums
  enum status: { pending: 0, applied: 1, rejected: 2, conflicted: 3 }
  enum operation_type: { 
    insert: 0, 
    delete: 1, 
    format: 2, 
    move: 3, 
    replace: 4,
    attribute_change: 5,
    structure_change: 6
  }
  
  # Validations
  validates :sequence_number, presence: true, uniqueness: { scope: :collaborative_session_id }
  validates :operation_id, presence: true, uniqueness: true
  validates :operation_type, presence: true
  validates :operation_data, presence: true
  validates :timestamp, presence: true
  
  # Scopes
  scope :by_session, ->(session) { where(collaborative_session: session) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(timestamp: :desc) }
  scope :in_sequence, -> { order(:sequence_number) }
  scope :conflicted, -> { where(has_conflict: true) }
  scope :unresolved_conflicts, -> { where(has_conflict: true, resolved_at: nil) }
  
  # Callbacks
  before_create :set_operation_id
  before_create :set_timestamp
  after_create :update_session_counters
  after_update :track_conflict_resolution
  
  def apply_to_content!
    return false unless pending?
    
    begin
      # Apply the operation using the appropriate applier
      applier = ContentOperationApplier.new(collaborative_session.collaboratable)
      result = applier.apply_operation(self)
      
      if result[:success]
        update!(
          status: 'applied',
          applied_at: Time.current,
          transformed_data: result[:transformed_data]
        )
        
        # Create success event
        create_operation_event('operation_applied', result)
        
        true
      else
        update!(
          status: 'rejected',
          conflict_data: result[:error_data]
        )
        
        # Create failure event
        create_operation_event('operation_rejected', result)
        
        false
      end
    rescue => e
      Rails.logger.error "Failed to apply operation #{operation_id}: #{e.message}"
      
      update!(
        status: 'rejected',
        conflict_data: { error: e.message, backtrace: e.backtrace.first(5) }
      )
      
      false
    end
  end
  
  def mark_conflicted!(conflict_info)
    update!(
      has_conflict: true,
      status: 'conflicted',
      conflict_data: conflict_info
    )
    
    create_operation_event('conflict_detected', conflict_info)
  end
  
  def resolve_conflict!(resolution_strategy, resolved_by_user)
    return false unless conflicted?
    
    resolver = ConflictResolver.new(self, resolution_strategy)
    resolution_result = resolver.resolve
    
    if resolution_result[:success]
      update!(
        has_conflict: false,
        status: 'applied',
        resolution_strategy: resolution_strategy,
        resolved_by: resolved_by_user,
        resolved_at: Time.current,
        conflict_data: conflict_data.merge(resolution_result[:resolution_data])
      )
      
      create_operation_event('conflict_resolved', resolution_result)
      
      # Increment session conflict counter
      collaborative_session.increment!(:total_conflicts_resolved)
      
      true
    else
      create_operation_event('conflict_resolution_failed', resolution_result)
      false
    end
  end
  
  def transform_against!(other_operation)
    return self if other_operation.sequence_number <= sequence_number
    
    transformer = OperationalTransformer.new(self, other_operation)
    transformation_result = transformer.transform
    
    if transformation_result[:success]
      update!(
        is_transformed: true,
        transformed_data: transformation_result[:transformed_operation],
        transformation_log: (transformation_log || []) << transformation_result[:log_entry],
        transform_generation: transform_generation + 1
      )
      
      create_operation_event('operation_transformed', transformation_result)
      
      self
    else
      mark_conflicted!(transformation_result[:conflict_info])
      self
    end
  end
  
  def can_be_applied?
    pending? && !has_conflict?
  end
  
  def affects_content_at?(path, position = nil)
    return false unless content_path == path
    return true if position.nil?
    
    case operation_type
    when 'insert'
      position >= start_position
    when 'delete'
      position >= start_position && position <= end_position
    when 'replace'
      position >= start_position && position <= end_position
    else
      true
    end
  end
  
  def content_range
    return nil unless start_position && end_position
    
    start_position..end_position
  end
  
  def operation_summary
    case operation_type
    when 'insert'
      "Insert #{operation_data['text']&.length || 0} characters at position #{start_position}"
    when 'delete'
      "Delete #{end_position - start_position} characters from #{start_position} to #{end_position}"
    when 'replace'
      "Replace #{end_position - start_position} characters with #{operation_data['new_text']&.length || 0} characters"
    when 'format'
      "Apply formatting: #{operation_data['format_type']}"
    when 'move'
      "Move content from #{start_position} to #{operation_data['target_position']}"
    else
      "#{operation_type.humanize} operation"
    end
  end
  
  def detailed_info
    {
      id: id,
      operation_id: operation_id,
      type: operation_type,
      sequence: sequence_number,
      user: {
        id: user.id,
        name: user.name
      },
      timestamp: timestamp,
      status: status,
      summary: operation_summary,
      content_path: content_path,
      position_range: content_range,
      has_conflict: has_conflict?,
      is_transformed: is_transformed?,
      data: operation_data,
      transformed_data: transformed_data
    }
  end
  
  def create_reverse_operation
    case operation_type
    when 'insert'
      {
        operation_type: 'delete',
        content_path: content_path,
        start_position: start_position,
        end_position: start_position + operation_data['text'].length,
        operation_data: {
          deleted_text: operation_data['text']
        }
      }
    when 'delete'
      {
        operation_type: 'insert',
        content_path: content_path,
        start_position: start_position,
        end_position: start_position,
        operation_data: {
          text: operation_data['deleted_text']
        }
      }
    when 'replace'
      {
        operation_type: 'replace',
        content_path: content_path,
        start_position: start_position,
        end_position: end_position,
        operation_data: {
          new_text: operation_data['old_text'],
          old_text: operation_data['new_text']
        }
      }
    else
      nil # Some operations may not be reversible
    end
  end
  
  private
  
  def set_operation_id
    self.operation_id ||= "op_#{SecureRandom.hex(8)}_#{Time.current.to_i}"
  end
  
  def set_timestamp
    self.timestamp ||= Time.current
  end
  
  def update_session_counters
    collaborative_session.increment!(:total_edits)
    
    # Update participant counters
    participant = collaborative_session.session_participants.find_by(user: user)
    participant&.increment!(:edits_count)
  end
  
  def track_conflict_resolution
    if resolved_at_changed? && resolved_at.present?
      create_operation_event('conflict_resolution_completed', {
        resolution_strategy: resolution_strategy,
        resolved_by: resolved_by.name,
        resolution_time: resolved_at
      })
    end
  end
  
  def create_operation_event(event_type, event_data)
    collaborative_session.collaboration_events.create!(
      user: user,
      event_type: event_type,
      event_data: event_data.merge({
        operation_id: operation_id,
        operation_type: operation_type,
        sequence_number: sequence_number
      }),
      related_operation: self,
      event_timestamp: Time.current
    )
  end
end