class CreateCursorPositions < ActiveRecord::Migration[8.0]
  def change
    create_table :cursor_positions do |t|
      t.references :collaborative_session, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      # Cursor position data
      t.json :position_data, null: false
      t.string :content_path # Path to the content being edited
      t.integer :line_number
      t.integer :column_number
      t.integer :character_offset
      
      # Selection data (if user has selected text)
      t.json :selection_data
      t.integer :selection_start
      t.integer :selection_end
      t.boolean :has_selection, default: false
      
      # Visual indicators
      t.string :cursor_color
      t.string :user_color
      t.boolean :is_typing, default: false
      t.timestamp :last_typing_at
      
      # Activity tracking
      t.timestamp :last_moved_at
      t.integer :movement_count, default: 0
      
      t.timestamps
    end
    
    # Unique constraint - one cursor per user per session
    add_index :cursor_positions, [:collaborative_session_id, :user_id], 
              unique: true, name: 'idx_cursor_positions_unique'
    
    # Performance indexes
    add_index :cursor_positions, [:collaborative_session_id, :updated_at], 
              name: 'idx_cursor_positions_session_activity'
    add_index :cursor_positions, [:content_path, :character_offset], 
              name: 'idx_cursor_positions_content_location'
    add_index :cursor_positions, [:is_typing, :last_typing_at], 
              name: 'idx_cursor_positions_typing_activity'
  end
end