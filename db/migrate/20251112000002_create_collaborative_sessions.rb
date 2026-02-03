class CreateCollaborativeSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :collaborative_sessions do |t|
      # Polymorphic association to collaboratable content
      t.references :collaboratable, null: false, polymorphic: true, index: true
      
      # Session creator
      t.references :created_by, null: false, foreign_key: { to_table: :users }, index: true
      
      # Session identification
      t.string :session_token, null: false, index: { unique: true }
      t.string :session_name, limit: 200
      t.text :description
      
      # Session configuration
      t.integer :status, default: 0, null: false # active: 0, paused: 1, ended: 2
      t.integer :permission_level, default: 2 # view_only: 0, comment: 1, edit: 2, admin: 3
      t.integer :max_participants, default: 10
      
      # Session lifecycle
      t.timestamp :started_at
      t.timestamp :ended_at
      t.timestamp :last_activity_at
      
      # Content state management
      t.json :snapshot_data, default: {}
      t.timestamp :last_snapshot_at
      t.integer :current_version, default: 1
      
      # Session settings
      t.boolean :auto_save_enabled, default: true
      t.integer :auto_save_interval, default: 30 # seconds
      t.boolean :conflict_resolution_enabled, default: true
      t.string :conflict_resolution_strategy, default: 'operational_transform'
      
      # Analytics
      t.integer :total_edits, default: 0
      t.integer :total_comments, default: 0
      t.integer :total_conflicts_resolved, default: 0
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :collaborative_sessions, [:collaboratable_type, :collaboratable_id, :status], 
              name: 'idx_collab_sessions_content_status'
    add_index :collaborative_sessions, [:created_by_id, :status], name: 'idx_collab_sessions_creator_status'
    add_index :collaborative_sessions, [:last_activity_at], name: 'idx_collab_sessions_activity'
    add_index :collaborative_sessions, [:started_at, :ended_at], name: 'idx_collab_sessions_duration'
  end
end