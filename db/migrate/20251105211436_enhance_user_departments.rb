class EnhanceUserDepartments < ActiveRecord::Migration[8.0]
  def change
    # Add role field for department-specific role (not user's global role)
    add_column :user_departments, :role, :string, default: 'member'
    
    # Add status field to track active/inactive memberships
    add_column :user_departments, :status, :string, default: 'active'
    
    # Add joined_at to track when user joined the department
    add_column :user_departments, :joined_at, :datetime
    
    # Add left_at to track when user left (if status becomes inactive)
    add_column :user_departments, :left_at, :datetime
    
    # Add invited_by to track who added this user
    add_column :user_departments, :invited_by_id, :integer
    add_foreign_key :user_departments, :users, column: :invited_by_id
    
    # Add notes field for any special remarks
    add_column :user_departments, :notes, :text
    
    # Add index for faster queries
    add_index :user_departments, :status
    add_index :user_departments, :role
    add_index :user_departments, :invited_by_id
  end
end
