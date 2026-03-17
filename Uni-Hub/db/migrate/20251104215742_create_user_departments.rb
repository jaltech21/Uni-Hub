class CreateUserDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :user_departments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
    
    # Ensure a user can only be assigned to a department once
    add_index :user_departments, [:user_id, :department_id], unique: true
  end
end
