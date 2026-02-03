class CreateNoteDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :note_departments do |t|
      t.references :note, null: false, foreign_key: true, index: true
      t.references :department, null: false, foreign_key: true, index: true
      t.references :shared_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :permission_level, default: 'view', null: false  # view, edit, manage
      
      t.timestamps
    end
    
    add_index :note_departments, [:note_id, :department_id], unique: true
  end
end
