class CreateComplianceFrameworks < ActiveRecord::Migration[8.0]
  def change
    create_table :compliance_frameworks do |t|
      t.string :name, null: false, limit: 255
      t.string :framework_type, null: false, limit: 100
      t.string :regulatory_body, null: false, limit: 255
      t.string :version, limit: 50
      t.date :effective_date, null: false
      t.json :requirements, default: []
      t.json :assessment_criteria, default: {}
      t.string :reporting_frequency, null: false, limit: 50
      t.string :status, null: false, default: 'active', limit: 30
      t.text :description
      t.date :expiry_date
      t.integer :assessment_cycle_months, default: 12
      t.decimal :compliance_threshold, precision: 5, scale: 2, default: 80.0
      t.boolean :mandatory, default: true
      t.json :notification_settings, default: {}

      t.timestamps
    end

    add_index :compliance_frameworks, :framework_type
    add_index :compliance_frameworks, :regulatory_body
    add_index :compliance_frameworks, :status
    add_index :compliance_frameworks, :effective_date
    add_index :compliance_frameworks, [:framework_type, :status], name: 'idx_frameworks_type_status'
  end
end
