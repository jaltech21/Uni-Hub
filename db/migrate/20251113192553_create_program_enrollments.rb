class CreateProgramEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :program_enrollments do |t|
      t.references :campus_program, null: false, foreign_key: true, index: { name: 'idx_enrollments_on_program' }
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'active', limit: 30
      t.date :enrollment_date, null: false
      t.date :expected_graduation
      t.date :graduation_date
      t.date :withdrawal_date
      t.decimal :final_gpa, precision: 3, scale: 2
      t.text :notes
      t.integer :credits_completed, default: 0
      t.decimal :current_gpa, precision: 3, scale: 2

      t.timestamps
    end

    add_index :program_enrollments, [:campus_program_id, :user_id], 
              unique: true, name: 'idx_unique_program_enrollment'
    add_index :program_enrollments, :status
    add_index :program_enrollments, :enrollment_date
    add_index :program_enrollments, :graduation_date
    add_index :program_enrollments, [:status, :enrollment_date], name: 'idx_enrollments_status_date'
  end
end
