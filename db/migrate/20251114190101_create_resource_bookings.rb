class CreateResourceBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :resource_bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bookable, polymorphic: true, null: false
      t.string :booking_type, null: false, limit: 50
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :status, null: false, default: 'pending', limit: 30
      t.string :purpose, null: false, limit: 255
      t.text :notes
      t.string :priority, default: 'normal', limit: 20
      t.json :recurrence, default: {}
      t.string :approval_status, default: 'pending', limit: 30
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.text :approval_notes
      t.decimal :total_cost, precision: 10, scale: 2, default: 0.0
      t.integer :attendee_count, default: 1
      t.string :contact_email, limit: 255
      t.string :contact_phone, limit: 20
      t.boolean :setup_required, default: false
      t.json :setup_requirements, default: []
      t.datetime :check_in_time
      t.datetime :check_out_time
      t.string :booking_reference, limit: 50

      t.timestamps
    end

    add_index :resource_bookings, [:bookable_type, :bookable_id], name: 'idx_bookings_on_bookable'
    add_index :resource_bookings, [:start_time, :end_time], name: 'idx_bookings_time_range'
    add_index :resource_bookings, :status
    add_index :resource_bookings, :approval_status
    add_index :resource_bookings, :user_id, name: 'idx_bookings_by_user'
    add_index :resource_bookings, :booking_reference, unique: true
    add_index :resource_bookings, [:bookable_type, :bookable_id, :start_time, :end_time], 
              name: 'idx_bookings_conflict_check'
  end
end
