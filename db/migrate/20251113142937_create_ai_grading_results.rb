class CreateAiGradingResults < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_grading_results do |t|
      t.references :submission, null: false, foreign_key: true
      t.references :grading_rubric, null: false, foreign_key: true
      t.decimal :ai_score, precision: 8, scale: 2
      t.decimal :confidence_score, precision: 5, scale: 3
      t.text :ai_feedback
      t.string :processing_status, default: 'pending'
      t.datetime :processed_at
      t.boolean :requires_review, default: false
      t.string :review_status, default: 'pending'
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :instructor_notes
      t.string :ai_provider, default: 'openai'
      t.integer :processing_time_seconds
      t.text :error_message
      t.json :detailed_scores
      t.boolean :grade_applied, default: false

      t.timestamps
    end

    add_index :ai_grading_results, [:submission_id, :grading_rubric_id], unique: true
    add_index :ai_grading_results, :processing_status
    add_index :ai_grading_results, :requires_review
    add_index :ai_grading_results, :review_status
    add_index :ai_grading_results, :confidence_score
    add_index :ai_grading_results, :processed_at
  end
end
