class SessionParticipant < ApplicationRecord
  belongs_to :collaborative_session
  belongs_to :user
  belongs_to :invited_by, class_name: 'User', optional: true
  
  # Enums
  enum permission_level: { view_only: 0, comment: 1, edit: 2, admin: 3 }
  enum status: { active: 0, away: 1, left: 2, kicked: 3 }
  
  # Validations
  validates :joined_at, presence: true
  validates :permission_level, presence: true
  validates :status, presence: true
  
  # Scopes
  scope :active_participants, -> { where(status: 'active') }
  scope :by_permission, ->(level) { where(permission_level: level) }
  scope :recently_active, -> { where('last_seen_at > ?', 5.minutes.ago) }
  
  # Callbacks
  before_create :set_joined_timestamp
  after_update :track_status_changes
  after_update :update_session_activity
  
  def online?
    active? && last_seen_at && last_seen_at > 2.minutes.ago
  end
  
  def can_edit?
    %w[edit admin].include?(permission_level)
  end
  
  def can_comment?
    %w[comment edit admin].include?(permission_level)
  end
  
  def can_admin?
    admin?
  end
  
  def session_duration
    return 0 unless joined_at
    
    end_time = left_at || Time.current
    ((end_time - joined_at) / 1.minute).round(2)
  end
  
  def update_last_seen!
    update!(last_seen_at: Time.current)
  end
  
  def leave_session!(reason = 'user_action')
    update!(
      status: 'left',
      left_at: Time.current
    )
    
    # Create leave event
    collaborative_session.collaboration_events.create!(
      user: user,
      event_type: 'participant_left',
      event_data: {
        reason: reason,
        session_duration: session_duration
      },
      event_timestamp: Time.current
    )
  end
  
  def kick_from_session!(kicked_by_user, reason = nil)
    return false unless kicked_by_user != user
    
    update!(
      status: 'kicked',
      left_at: Time.current
    )
    
    # Create kick event
    collaborative_session.collaboration_events.create!(
      user: kicked_by_user,
      event_type: 'participant_kicked',
      event_data: {
        kicked_user_id: user.id,
        reason: reason
      },
      event_timestamp: Time.current
    )
    
    true
  end
  
  def promote_permission!(new_level, promoted_by_user)
    return false unless %w[view_only comment edit admin].include?(new_level)
    return false if permission_level == new_level
    
    old_level = permission_level
    update!(permission_level: new_level)
    
    # Create permission change event
    collaborative_session.collaboration_events.create!(
      user: promoted_by_user,
      event_type: 'permission_changed',
      event_data: {
        target_user_id: user.id,
        old_permission: old_level,
        new_permission: new_level
      },
      event_timestamp: Time.current
    )
    
    true
  end
  
  def activity_summary
    {
      duration: session_duration,
      edits_count: edits_count,
      comments_count: comments_count,
      cursor_updates: cursor_updates_count,
      last_seen: last_seen_at,
      online: online?,
      permission: permission_level,
      status: status
    }
  end
  
  def user_snapshot
    {
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar.attached? ? user.avatar.url : nil,
      permission: permission_level,
      status: status,
      joined_at: joined_at,
      last_seen_at: last_seen_at,
      online: online?,
      activity: {
        edits: edits_count,
        comments: comments_count,
        cursor_updates: cursor_updates_count
      }
    }
  end
  
  private
  
  def set_joined_timestamp
    self.joined_at ||= Time.current
    self.last_seen_at ||= Time.current
  end
  
  def track_status_changes
    if status_changed? && status_changed_from_active?
      collaborative_session.collaboration_events.create!(
        user: user,
        event_type: "participant_#{status}",
        event_data: {
          previous_status: status_was,
          duration_in_session: session_duration
        },
        event_timestamp: Time.current
      )
    end
  end
  
  def status_changed_from_active?
    status_was == 'active' && status != 'active'
  end
  
  def update_session_activity
    if last_seen_at_changed?
      collaborative_session.update!(last_activity_at: Time.current)
    end
  end
end