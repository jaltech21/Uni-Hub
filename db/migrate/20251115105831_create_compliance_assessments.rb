class CreateComplianceAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_assessments do |t|
      t.references :compliance_framework, null: false, foreign_key: true
      t.references :campus, null: true, foreign_key: { to_table: :campuses }
      t.references :department, null: true, foreign_key: true
      t.string :assessment_type, null: false, limit: 50
      t.string :status, null: false, default: 'scheduled', limit: 30
      t.decimal :score, precision: 5, scale: 2
      t.json :findings, default: []
      t.json :recommendations, default: []
      t.references :assessor, null: false, foreign_key: { to_table: :users }
      t.date :assessment_date, null: false
      t.date :due_date
      t.date :completion_date
      t.text :executive_summary
      t.json :evidence, default: []
      t.json :action_items, default: []
      t.integer :priority, default: 2
      t.boolean :passed, default: false
      t.text :assessor_notes
      t.string :certification_status, limit: 30

      t.timestamps
    end

    add_index :compliance_assessments, :assessment_type
    add_index :compliance_assessments, :status
    add_index :compliance_assessments, :assessment_date
    add_index :compliance_assessments, :due_date
    add_index :compliance_assessments, [:status, :due_date], name: 'idx_assessments_status_due'
    add_index :compliance_assessments, :passed
  end
end
