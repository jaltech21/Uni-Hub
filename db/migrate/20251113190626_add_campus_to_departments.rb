class AddCampusToDepartments < ActiveRecord::Migration[8.0]
  def change
    add_reference :departments, :campus, null: true, foreign_key: { to_table: :campuses }
    add_index :departments, [:campus_id, :name]
  end
end
