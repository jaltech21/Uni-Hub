class CreateRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :rooms do |t|
      t.string :name, null: false, limit: 255
      t.string :code, null: false, limit: 50
      t.references :campus, null: false, foreign_key: { to_table: :campuses }
      t.string :building, null: false, limit: 100
      t.integer :floor
      t.string :room_type, null: false, limit: 50
      t.integer :capacity, null: false, default: 1
      t.json :equipment, default: []
      t.json :amenities, default: []
      t.json :availability_hours, default: {}
      t.json :booking_rules, default: {}
      t.string :status, null: false, default: 'available', limit: 30
      t.boolean :requires_approval, default: false
      t.decimal :hourly_rate, precision: 8, scale: 2
      t.text :description
      t.string :access_level, limit: 30, default: 'public'
      t.integer :advance_booking_days, default: 30
      t.integer :max_booking_duration_hours, default: 8

      t.timestamps
    end

    add_index :rooms, [:campus_id, :code], unique: true, name: 'idx_unique_room_code_per_campus'
    add_index :rooms, :room_type
    add_index :rooms, :status
    add_index :rooms, :capacity
    add_index :rooms, [:building, :floor], name: 'idx_rooms_building_floor'
    add_index :rooms, :requires_approval
  end
end
