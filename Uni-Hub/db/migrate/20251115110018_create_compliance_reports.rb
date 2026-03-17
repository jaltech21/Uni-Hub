class CreateComplianceReports < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_reports do |t|
      t.references :compliance_framework, null: false, foreign_key: true
      t.references :campus, null: true, foreign_key: { to_table: :campuses }
      t.string :report_type, null: false, limit: 50
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.references :generated_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: 'draft', limit: 30
      t.json :content, default: {}
      t.text :executive_summary
      t.json :recommendations, default: []
      t.decimal :overall_compliance_score, precision: 5, scale: 2
      t.integer :total_assessments, default: 0
      t.integer :passed_assessments, default: 0
      t.json :key_metrics, default: {}
      t.json :trend_analysis, default: {}
      t.string :file_path, limit: 500
      t.boolean :auto_generated, default: false
      t.datetime :published_at
      t.string :report_format, limit: 20, default: 'pdf'

      t.timestamps
    end

    add_index :compliance_reports, :report_type
    add_index :compliance_reports, :status
    add_index :compliance_reports, [:period_start, :period_end], name: 'idx_reports_period'
    add_index :compliance_reports, :published_at
    add_index :compliance_reports, :auto_generated
  end
end
