class CreateEditOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :edit_operations do |t|
      t.references :collaborative_session, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      # Operation identification and ordering
      t.bigint :sequence_number, null: false
      t.string :operation_id, null: false, index: true
      t.references :parent_operation, null: true, foreign_key: { to_table: :edit_operations }
      
      # Operation details
      t.string :operation_type, null: false # insert, delete, format, move, replace
      t.json :operation_data, null: false
      t.json :transformed_data # After operational transformation
      
      # Content location
      t.string :content_path # e.g., "content.paragraphs.0.text"
      t.integer :start_position
      t.integer :end_position
      
      # Operation state
      t.integer :status, default: 0 # pending: 0, applied: 1, rejected: 2, conflicted: 3
      t.timestamp :applied_at
      t.timestamp :timestamp, null: false
      
      # Conflict resolution
      t.boolean :has_conflict, default: false
      t.json :conflict_data
      t.string :resolution_strategy
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.timestamp :resolved_at
      
      # Operational transformation
      t.boolean :is_transformed, default: false
      t.json :transformation_log
      t.integer :transform_generation, default: 0
      
      # Metadata
      t.string :client_id # For tracking client-side operations
      t.json :metadata, default: {}
      
      t.timestamps
    end
    
    # Unique constraint for sequence numbers per session
    add_index :edit_operations, [:collaborative_session_id, :sequence_number], 
              unique: true, name: 'idx_edit_ops_session_sequence'
    
    # Performance indexes
    add_index :edit_operations, [:collaborative_session_id, :timestamp], 
              name: 'idx_edit_ops_session_time'
    add_index :edit_operations, [:user_id, :timestamp], name: 'idx_edit_ops_user_time'
    add_index :edit_operations, [:operation_type, :status], name: 'idx_edit_ops_type_status'
    add_index :edit_operations, [:has_conflict, :status], name: 'idx_edit_ops_conflicts'
    add_index :edit_operations, [:content_path, :start_position], name: 'idx_edit_ops_content_location'
  end
end