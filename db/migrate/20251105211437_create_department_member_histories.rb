class CreateDepartmentMemberHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :department_member_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.string :action, null: false  # added, removed, role_changed, status_changed, imported
      t.references :performed_by, foreign_key: { to_table: :users }
      t.jsonb :details, default: {}

      t.timestamps
    end
    
    add_index :department_member_histories, :action
    add_index :department_member_histories, :created_at
  end
end
