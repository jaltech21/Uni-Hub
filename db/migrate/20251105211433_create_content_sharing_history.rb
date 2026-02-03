class CreateContentSharingHistory < ActiveRecord::Migration[8.0]
  def change
    create_table :content_sharing_histories do |t|
      t.references :shareable, polymorphic: true, null: false, index: true
      t.references :department, null: false, foreign_key: true, index: true
      t.references :shared_by, null: false, foreign_key: { to_table: :users }, index: true
      t.string :action, null: false  # 'shared', 'unshared', 'permission_changed'
      t.string :permission_level
      t.text :notes
      
      t.timestamps
    end
    
    add_index :content_sharing_histories, :created_at
  end
end
