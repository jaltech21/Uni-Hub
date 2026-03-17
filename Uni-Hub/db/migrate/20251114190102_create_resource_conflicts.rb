class CreateResourceConflicts < ActiveRecord::Migration[8.0]
  def change
    create_table :resource_conflicts do |t|
      t.references :primary_booking, null: false, foreign_key: { to_table: :resource_bookings }
      t.references :conflicting_booking, null: false, foreign_key: { to_table: :resource_bookings }
      t.string :conflict_type, null: false, limit: 50
      t.string :severity, null: false, default: 'medium', limit: 20
      t.string :resolution_status, null: false, default: 'unresolved', limit: 30
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }
      t.text :resolution_notes
      t.datetime :detected_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :resolved_at
      t.string :resolution_action, limit: 100
      t.json :conflict_details, default: {}
      t.boolean :auto_resolved, default: false
      t.decimal :resolution_cost, precision: 8, scale: 2

      t.timestamps
    end

    add_index :resource_conflicts, :conflict_type
    add_index :resource_conflicts, :severity
    add_index :resource_conflicts, :resolution_status
    add_index :resource_conflicts, :detected_at
    add_index :resource_conflicts, [:primary_booking_id, :conflicting_booking_id], 
              unique: true, name: 'idx_unique_conflict_pair'
  end
end
