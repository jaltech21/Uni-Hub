class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.text :content
      t.string :message_type
      t.integer :thread_id
      t.datetime :read_at

      t.timestamps
    end
    
    add_index :messages, [:sender_id, :recipient_id]
    add_index :messages, [:thread_id]
    add_index :messages, [:read_at]
  end
end
