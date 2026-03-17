class CreateSessionParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :session_participants do |t|
      t.references :collaborative_session, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      # Participant role and permissions
      t.integer :permission_level, default: 2, null: false # view_only: 0, comment: 1, edit: 2, admin: 3
      t.integer :status, default: 0, null: false # active: 0, away: 1, left: 2, kicked: 3
      
      # Session participation tracking
      t.timestamp :joined_at, null: false
      t.timestamp :left_at
      t.timestamp :last_seen_at
      
      # Participant activity metrics
      t.integer :edits_count, default: 0
      t.integer :comments_count, default: 0
      t.integer :cursor_updates_count, default: 0
      
      # Participant preferences for this session
      t.json :preferences, default: {}
      t.text :notes # Private notes for this participant
      
      # Invitation tracking
      t.references :invited_by, null: true, foreign_key: { to_table: :users }
      t.timestamp :invited_at
      t.timestamp :invitation_accepted_at
      
      t.timestamps
    end
    
    # Unique constraint - one active participation per user per session
    add_index :session_participants, [:collaborative_session_id, :user_id], 
              unique: true, name: 'idx_session_participants_unique'
    
    # Performance indexes
    add_index :session_participants, [:collaborative_session_id, :status], 
              name: 'idx_session_participants_session_status'
    add_index :session_participants, [:user_id, :status, :joined_at], 
              name: 'idx_session_participants_user_activity'
    add_index :session_participants, [:last_seen_at], name: 'idx_session_participants_last_seen'
  end
end