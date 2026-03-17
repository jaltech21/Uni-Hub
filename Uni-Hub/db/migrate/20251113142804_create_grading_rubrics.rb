class CreateGradingRubrics < ActiveRecord::Migration[8.0]
  def change
    create_table :grading_rubrics do |t|
      t.string :name, null: false
      t.references :assignment, null: true, foreign_key: true
      t.string :content_type, default: 'general'
      t.string :rubric_type, default: 'analytic'
      t.text :criteria
      t.integer :total_points, default: 100
      t.boolean :ai_grading_enabled, default: false
      t.text :ai_prompt_template
      t.text :description
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.boolean :active, default: true
      t.references :department, null: true, foreign_key: true
      t.string :ai_provider, default: 'openai'
      t.integer :usage_count, default: 0
      t.decimal :average_confidence, precision: 5, scale: 3, default: 0.0

      t.timestamps
    end

    add_index :grading_rubrics, [:assignment_id, :active], name: 'idx_rubrics_assignment_active'
    add_index :grading_rubrics, [:department_id, :content_type], name: 'idx_rubrics_dept_content'
    add_index :grading_rubrics, [:ai_grading_enabled, :active], name: 'idx_rubrics_ai_active'
  end
end
