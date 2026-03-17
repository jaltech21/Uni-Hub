class CreateDiscussions < ActiveRecord::Migration[8.0]
  def change
    create_table :discussions do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.references :user, null: false, foreign_key: true
      t.string :category, null: false, default: 'general'
      t.string :status, null: false, default: 'open'
      t.integer :views_count, default: 0

      t.timestamps
    end
    
    add_index :discussions, [:category]
    add_index :discussions, [:status]
    add_index :discussions, [:created_at]
    add_index :discussions, [:updated_at]
    add_index :discussions, [:views_count]
  end
end
