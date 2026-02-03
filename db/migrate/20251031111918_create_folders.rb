class CreateFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :folders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :color, default: '#3B82F6' # Default blue color
      t.integer :position, default: 0

      t.timestamps
    end
    
    add_index :folders, [:user_id, :name], unique: true
    add_index :folders, [:user_id, :position]
  end
end
