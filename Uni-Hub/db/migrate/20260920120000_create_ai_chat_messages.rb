class CreateAiChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_chat_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'user' # user | assistant | system
      t.text :content, null: false
      t.string :mode, default: 'assistant'
      t.string :status, default: 'completed'
      t.integer :processing_time_ms
      t.integer :tokens_used
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :ai_chat_messages, [:user_id, :created_at]
  end
end