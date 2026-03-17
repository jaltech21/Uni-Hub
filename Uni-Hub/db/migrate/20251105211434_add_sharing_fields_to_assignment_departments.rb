class AddSharingFieldsToAssignmentDepartments < ActiveRecord::Migration[8.0]
  def change
    add_reference :assignment_departments, :shared_by, foreign_key: { to_table: :users }, index: true
    add_column :assignment_departments, :permission_level, :string, default: 'view', null: false
  end
end
