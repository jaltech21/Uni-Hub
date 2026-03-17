class CreateCampuses < ActiveRecord::Migration[8.0]
  def change
    create_table :campuses do |t|
      t.string :name, null: false
      t.string :code, null: false, limit: 10
      t.text :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: 'US'
      t.string :phone
      t.string :email
      t.string :website
      t.string :timezone, default: 'UTC'
      t.boolean :is_main_campus, default: false
      t.boolean :active, default: true
      t.references :university, null: false, foreign_key: true
      
      # Additional fields for campus management
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.integer :student_capacity
      t.integer :faculty_count, default: 0
      t.integer :staff_count, default: 0
      t.date :established_date
      t.text :facilities_description
      t.string :accreditation_status
      t.json :contact_persons
      t.json :operating_hours

      t.timestamps
    end

    add_index :campuses, [:university_id, :code], unique: true
    add_index :campuses, [:university_id, :is_main_campus]
    add_index :campuses, :active
    add_index :campuses, [:latitude, :longitude]
    add_index :campuses, :established_date
  end
end
