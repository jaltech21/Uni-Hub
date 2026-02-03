class CreateAiUsageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_usage_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.string :status
      t.text :request_details
      t.text :response_details
      t.text :error_message
      t.float :processing_time
      t.integer :tokens_used

      t.timestamps
    end
  end
end
