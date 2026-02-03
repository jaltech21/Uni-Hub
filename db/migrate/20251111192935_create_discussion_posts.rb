class CreateDiscussionPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :discussion_posts do |t|
      t.references :discussion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.integer :parent_id

      t.timestamps
    end
    
    add_index :discussion_posts, [:discussion_id, :parent_id]
    add_index :discussion_posts, [:parent_id]
    add_index :discussion_posts, [:created_at]
    add_foreign_key :discussion_posts, :discussion_posts, column: :parent_id
  end
end
