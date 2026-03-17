class AddRoleAndDepartmentToUsers < ActiveRecord::Migration[8.0]
  def change
    # Role column already exists, only add department
    add_reference :users, :department, foreign_key: true, null: true
    
    add_index :users, :role unless index_exists?(:users, :role)
    add_index :users, [:department_id, :role]
  end
end
