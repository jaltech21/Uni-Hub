class AddDepartmentToContent < ActiveRecord::Migration[8.0]
  def change
    # Add department_id to all content tables (nullable for backward compatibility)
    add_reference :assignments, :department, foreign_key: true, null: true
    add_reference :notes, :department, foreign_key: true, null: true
    add_reference :quizzes, :department, foreign_key: true, null: true
    add_reference :schedules, :department, foreign_key: true, null: true
    
    # Add indexes for performance
    add_index :assignments, [:department_id, :created_at]
    add_index :notes, [:department_id, :created_at]
    add_index :quizzes, [:department_id, :created_at]
    add_index :schedules, [:department_id, :created_at]
  end
end
