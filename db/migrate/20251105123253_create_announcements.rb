class CreateAnnouncements < ActiveRecord::Migration[8.0]
  def change
    create_table :announcements do |t|
      t.references :department, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content, null: false
      t.string :priority, default: 'normal', null: false  # low, normal, high, urgent
      t.boolean :pinned, default: false, null: false
      t.datetime :expires_at
      t.datetime :published_at
      
      t.timestamps
    end
    
    add_index :announcements, [:department_id, :pinned, :published_at]
    add_index :announcements, [:department_id, :priority]
  end
end
