class CreatePlagiarismChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :plagiarism_checks do |t|
      t.references :submission, null: false, foreign_key: true
      t.decimal :similarity_percentage, precision: 5, scale: 2, default: 0.0
      t.text :flagged_sections
      t.text :sources_found
      t.string :processing_status, default: 'pending'
      t.datetime :processed_at
      t.boolean :requires_review, default: false
      t.string :review_status, default: 'pending'
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :instructor_notes
      t.text :ai_detection_results
      t.string :escalation_level
      t.datetime :escalated_at
      t.boolean :recheck_performed, default: false
      t.decimal :recheck_similarity, precision: 5, scale: 2
      t.datetime :recheck_date
      t.integer :processing_time_seconds
      t.text :error_message

      t.timestamps
    end

    add_index :plagiarism_checks, :processing_status, name: 'idx_plagiarism_status'
    add_index :plagiarism_checks, :requires_review, name: 'idx_plagiarism_review_required'
    add_index :plagiarism_checks, :review_status, name: 'idx_plagiarism_review_status'
    add_index :plagiarism_checks, :similarity_percentage, name: 'idx_plagiarism_similarity'
    add_index :plagiarism_checks, :escalation_level, name: 'idx_plagiarism_escalation'
    add_index :plagiarism_checks, :processed_at, name: 'idx_plagiarism_processed_at'
  end
end
