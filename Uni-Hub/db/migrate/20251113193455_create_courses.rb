class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.string :code, null: false, limit: 20
      t.string :name, null: false, limit: 255
      t.text :description
      t.integer :credits, null: false
      t.integer :duration_weeks, default: 16
      t.string :level, limit: 30
      t.references :department, null: false, foreign_key: true
      t.boolean :active, default: true
      t.string :delivery_method, limit: 20, default: 'in_person'
      t.json :prerequisites
      t.decimal :tuition_cost, precision: 10, scale: 2
      t.integer :max_students
      t.string :instructor_requirements, limit: 500

      t.timestamps
    end

    add_index :courses, [:department_id, :code], unique: true, name: 'idx_unique_course_code_per_department'
    add_index :courses, :level
    add_index :courses, :active
    add_index :courses, :delivery_method
    add_index :courses, :credits
  end
end
