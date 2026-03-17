class CreateQuizDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_departments do |t|
      t.references :quiz, null: false, foreign_key: true, index: true
      t.references :department, null: false, foreign_key: true, index: true
      t.references :shared_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :permission_level, default: 'view', null: false  # view, take, manage
      
      t.timestamps
    end
    
    add_index :quiz_departments, [:quiz_id, :department_id], unique: true
  end
end
