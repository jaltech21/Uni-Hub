class CreateProgramCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :program_courses do |t|
      t.references :campus_program, null: false, foreign_key: true, index: { name: 'idx_program_courses_on_program' }
      t.references :course, null: false, foreign_key: true
      t.string :course_type, null: false, default: 'required', limit: 30
      t.integer :credits, null: false
      t.boolean :required, default: false
      t.integer :semester, default: 1
      t.integer :year, default: 1
      t.text :prerequisites
      t.text :notes

      t.timestamps
    end

    add_index :program_courses, [:campus_program_id, :course_id], 
              unique: true, name: 'idx_unique_program_course'
    add_index :program_courses, :course_type
    add_index :program_courses, :required
    add_index :program_courses, [:semester, :year], name: 'idx_program_courses_semester_year'
  end
end
