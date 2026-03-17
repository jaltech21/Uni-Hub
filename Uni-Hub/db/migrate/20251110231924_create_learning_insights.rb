class CreateLearningInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :learning_insights do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: true, foreign_key: true
      t.references :schedule, null: true, foreign_key: true
      t.string :insight_type, null: false
      t.decimal :confidence_score, precision: 3, scale: 2, null: false
      t.string :priority, null: false
      t.string :status, null: false, default: 'active'
      t.text :data
      t.text :recommendations
      t.text :metadata
      t.datetime :dismissed_at
      t.datetime :implemented_at
      t.datetime :archived_at

      t.timestamps
    end
    
    # Add indexes for better query performance
    add_index :learning_insights, [:user_id, :status]
    add_index :learning_insights, [:insight_type, :priority]
    add_index :learning_insights, [:department_id, :status]
    add_index :learning_insights, :confidence_score
    add_index :learning_insights, :created_at
  end
end
