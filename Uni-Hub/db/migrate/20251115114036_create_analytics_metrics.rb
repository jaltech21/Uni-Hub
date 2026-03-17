class CreateAnalyticsMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_metrics do |t|
      t.string :metric_name
      t.string :metric_type
      t.string :entity_type
      t.integer :entity_id
      t.decimal :value
      t.json :metadata
      t.timestamp :recorded_at
      t.references :campus, null: true, foreign_key: { to_table: :campuses }
      t.references :department, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
    
    add_index :analytics_metrics, [:metric_name, :recorded_at]
    add_index :analytics_metrics, [:entity_type, :entity_id]
    add_index :analytics_metrics, :metric_type
    add_index :analytics_metrics, :recorded_at
  end
end
