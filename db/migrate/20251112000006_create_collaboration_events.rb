class CreateCollaborationEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :collaboration_events do |t|
      t.references :collaborative_session, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      # Event classification
      t.string :event_type, null: false # join, leave, edit, comment, conflict, snapshot, etc.
      t.string :event_category, default: 'general' # system, user_action, content_change, session_management
      t.integer :severity, default: 0 # info: 0, warning: 1, error: 2, critical: 3
      
      # Event data
      t.json :event_data, default: {}
      t.text :description
      t.string :summary, limit: 500
      
      # Event relationships
      t.references :related_operation, null: true, foreign_key: { to_table: :edit_operations }
      t.string :related_entity_type
      t.bigint :related_entity_id
      
      # Event metadata
      t.timestamp :event_timestamp, null: false
      t.string :source, default: 'system' # system, user, api, webhook
      t.string :client_info # Browser, IP, etc.
      
      # Event processing
      t.boolean :is_processed, default: false
      t.timestamp :processed_at
      t.json :processing_result
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :collaboration_events, [:collaborative_session_id, :event_timestamp], 
              name: 'idx_collab_events_session_time'
    add_index :collaboration_events, [:event_type, :event_timestamp], 
              name: 'idx_collab_events_type_time'
    add_index :collaboration_events, [:user_id, :event_timestamp], 
              name: 'idx_collab_events_user_time'
    add_index :collaboration_events, [:related_entity_type, :related_entity_id], 
              name: 'idx_collab_events_related_entity'
    add_index :collaboration_events, [:severity, :is_processed], 
              name: 'idx_collab_events_severity_processing'
  end
end