class CreateCampusPrograms < ActiveRecord::Migration[8.0]
  def change
    create_table :campus_programs do |t|
      t.string :name, null: false
      t.string :code, null: false, limit: 20
      t.text :description
      t.string :degree_level, null: false # bachelor, master, doctoral, certificate
      t.integer :duration_months, null: false
      t.integer :credits_required, null: false
      t.references :campus, null: false, foreign_key: { to_table: :campuses }
      t.references :department, null: false, foreign_key: true
      t.boolean :active, default: true
      
      # Program management fields
      t.decimal :tuition_per_credit, precision: 8, scale: 2
      t.integer :max_enrollment
      t.integer :current_enrollment, default: 0
      t.date :program_start_date
      t.string :delivery_method # on_campus, online, hybrid
      t.text :admission_requirements
      t.text :graduation_requirements
      t.json :program_outcomes
      t.string :accreditation_body
      t.date :last_accredited
      t.date :next_review_date
      t.references :program_director, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :campus_programs, [:campus_id, :code], unique: true
    add_index :campus_programs, [:campus_id, :degree_level]
    add_index :campus_programs, [:department_id, :active]
    add_index :campus_programs, :delivery_method
    add_index :campus_programs, :program_director_id, name: 'idx_campus_programs_director'
  end
end
