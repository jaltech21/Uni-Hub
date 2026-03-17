class CursorPosition < ApplicationRecord
  belongs_to :collaborative_session
  belongs_to :user
  
  # Validations
  validates :position_data, presence: true
  validates :character_offset, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :line_number, numericality: { greater_than: 0 }, allow_nil: true
  validates :column_number, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes
  scope :active_cursors, -> { where('updated_at > ?', 30.seconds.ago) }
  scope :typing_users, -> { where(is_typing: true, 'last_typing_at > ?', 10.seconds.ago) }
  scope :by_content_path, ->(path) { where(content_path: path) }
  
  # Callbacks
  before_save :update_movement_tracking
  after_update :broadcast_cursor_update
  after_update :update_participant_activity
  
  def active?
    updated_at > 30.seconds.ago
  end
  
  def recently_typing?
    is_typing? && last_typing_at && last_typing_at > 10.seconds.ago
  end
  
  def start_typing!
    update!(
      is_typing: true,
      last_typing_at: Time.current
    )
  end
  
  def stop_typing!
    update!(
      is_typing: false
    )
  end
  
  def update_position!(new_position_data)
    old_position = position_data.dup if position_data.present?
    
    self.position_data = new_position_data
    self.character_offset = new_position_data['character_offset'] if new_position_data['character_offset']
    self.line_number = new_position_data['line_number'] if new_position_data['line_number']
    self.column_number = new_position_data['column_number'] if new_position_data['column_number']
    self.content_path = new_position_data['content_path'] if new_position_data['content_path']
    self.last_moved_at = Time.current
    
    # Update selection if present
    if new_position_data['selection']
      self.has_selection = true
      self.selection_data = new_position_data['selection']
      self.selection_start = new_position_data['selection']['start']
      self.selection_end = new_position_data['selection']['end']
    else
      self.has_selection = false
      self.selection_data = nil
      self.selection_start = nil
      self.selection_end = nil
    end
    
    save!
  end
  
  def update_selection!(selection_info)
    if selection_info && selection_info['start'] && selection_info['end']
      update!(
        has_selection: true,
        selection_data: selection_info,
        selection_start: selection_info['start'],
        selection_end: selection_info['end']
      )
    else
      update!(
        has_selection: false,
        selection_data: nil,
        selection_start: nil,
        selection_end: nil
      )
    end
  end
  
  def assign_user_color!
    # Assign a unique color for this user in this session
    used_colors = collaborative_session.cursor_positions
                                     .where.not(user: user)
                                     .pluck(:user_color)
                                     .compact
    
    available_colors = %w[
      #FF6B6B #4ECDC4 #45B7D1 #96CEB4 #FECA57 
      #FF9FF3 #54A0FF #5F27CD #00D2D3 #FF9F43
      #FC427B #26DE81 #FD79A8 #FDCB6E #6C5CE7
    ]
    
    new_color = (available_colors - used_colors).first || available_colors.sample
    
    update!(
      user_color: new_color,
      cursor_color: new_color
    )
    
    new_color
  end
  
  def position_info
    {
      user_id: user.id,
      user_name: user.name,
      user_color: user_color,
      position: position_data,
      character_offset: character_offset,
      line: line_number,
      column: column_number,
      content_path: content_path,
      has_selection: has_selection?,
      selection: selection_data,
      is_typing: recently_typing?,
      last_moved: last_moved_at,
      active: active?
    }
  end
  
  def overlaps_with?(other_cursor)
    return false unless other_cursor.is_a?(CursorPosition)
    return false unless content_path == other_cursor.content_path
    
    if has_selection? && other_cursor.has_selection?
      # Check if selections overlap
      !(selection_end < other_cursor.selection_start || selection_start > other_cursor.selection_end)
    elsif has_selection?
      # Check if other cursor is within this selection
      other_cursor.character_offset >= selection_start && other_cursor.character_offset <= selection_end
    elsif other_cursor.has_selection?
      # Check if this cursor is within other selection
      character_offset >= other_cursor.selection_start && character_offset <= other_cursor.selection_end
    else
      # Check if cursors are at the same position
      character_offset == other_cursor.character_offset
    end
  end
  
  def nearby_cursors(proximity_range = 50)
    collaborative_session.cursor_positions
                        .where.not(user: user)
                        .where(content_path: content_path)
                        .where(
                          'character_offset BETWEEN ? AND ?',
                          character_offset - proximity_range,
                          character_offset + proximity_range
                        )
                        .includes(:user)
  end
  
  def cursor_activity_summary
    {
      total_movements: movement_count,
      last_movement: last_moved_at,
      typing_sessions: calculate_typing_sessions,
      active_time: calculate_active_time,
      content_areas_visited: calculate_content_areas
    }
  end
  
  private
  
  def update_movement_tracking
    if position_data_changed? || character_offset_changed?
      self.movement_count += 1
      self.last_moved_at = Time.current
    end
  end
  
  def broadcast_cursor_update
    return unless saved_change_to_position_data? || saved_change_to_character_offset?
    
    ActionCable.server.broadcast(
      "collaboration_session_#{collaborative_session.session_token}",
      {
        type: 'cursor_update',
        cursor: position_info
      }
    )
  end
  
  def update_participant_activity
    if saved_change_to_updated_at?
      participant = collaborative_session.session_participants.find_by(user: user)
      if participant
        participant.increment!(:cursor_updates_count)
        participant.update_last_seen!
      end
    end
  end
  
  def calculate_typing_sessions
    # This would analyze typing patterns over time
    # For now, return a simple count
    is_typing? ? 1 : 0
  end
  
  def calculate_active_time
    # Calculate total time cursor has been active
    return 0 unless last_moved_at
    
    if active?
      ((Time.current - created_at) / 1.minute).round(2)
    else
      ((last_moved_at - created_at) / 1.minute).round(2)
    end
  end
  
  def calculate_content_areas
    # This would track different content paths visited
    # For now, return current path
    content_path ? [content_path] : []
  end
end