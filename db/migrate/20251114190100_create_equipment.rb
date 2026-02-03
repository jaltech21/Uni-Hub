class CreateEquipment < ActiveRecord::Migration[8.0]
  def change
    create_table :equipment do |t|
      t.string :name, null: false, limit: 255
      t.string :code, null: false, limit: 50
      t.string :equipment_type, null: false, limit: 100
      t.string :brand, limit: 100
      t.string :model, limit: 100
      t.references :campus, null: false, foreign_key: { to_table: :campuses }
      t.references :room, null: true, foreign_key: true
      t.string :status, null: false, default: 'available', limit: 30
      t.date :purchase_date
      t.date :warranty_expiry
      t.json :maintenance_schedule, default: {}
      t.json :specifications, default: {}
      t.json :booking_rules, default: {}
      t.decimal :purchase_cost, precision: 10, scale: 2
      t.decimal :hourly_rate, precision: 8, scale: 2
      t.text :description
      t.string :serial_number, limit: 100
      t.boolean :portable, default: false
      t.boolean :requires_training, default: false
      t.integer :max_booking_duration_hours, default: 4
      t.string :condition_rating, limit: 20, default: 'good'

      t.timestamps
    end

    add_index :equipment, [:campus_id, :code], unique: true, name: 'idx_unique_equipment_code_per_campus'
    add_index :equipment, :equipment_type
    add_index :equipment, :status
    add_index :equipment, :room_id, name: 'idx_equipment_room_assignment'
    add_index :equipment, :portable
    add_index :equipment, :requires_training
    add_index :equipment, :warranty_expiry
  end
end
