class CreateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.string :code, null: false, limit: 10
      t.text :description
      t.bigint :university_id
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :departments, [:university_id, :code], unique: true
    add_index :departments, :active
  end
end
