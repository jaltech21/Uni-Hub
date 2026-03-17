class CreateBusinessIntelligenceReports < ActiveRecord::Migration[8.0]
  def change
    create_table :business_intelligence_reports do |t|
      t.string :report_name
      t.string :report_type
      t.string :report_period
      t.references :generated_by, null: false, foreign_key: { to_table: :users }
      t.json :data_sources
      t.json :insights
      t.json :recommendations
      t.text :executive_summary
      t.string :status, default: 'generating'
      t.timestamp :generated_at
      t.references :campus, null: true, foreign_key: { to_table: :campuses }

      t.timestamps
    end
    
    add_index :business_intelligence_reports, [:report_type, :generated_at]
    add_index :business_intelligence_reports, :status
    add_index :business_intelligence_reports, :generated_at
  end
end
