class CreateAssignmentDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_departments do |t|
      t.references :assignment, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
    
    # Ensure an assignment can only be assigned to a department once
    add_index :assignment_departments, [:assignment_id, :department_id], unique: true, name: 'index_assignment_departments_unique'
  end
end
