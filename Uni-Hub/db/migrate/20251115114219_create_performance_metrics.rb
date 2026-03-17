class CreatePerformanceMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_metrics do |t|
      t.string :metric_type
      t.string :endpoint_path
      t.decimal :response_time, precision: 10, scale: 3
      t.decimal :memory_usage, precision: 10, scale: 2
      t.decimal :cpu_usage, precision: 5, scale: 2
      t.integer :query_count, default: 0
      t.integer :error_count, default: 0
      t.timestamp :recorded_at
      t.json :optimization_suggestions

      t.timestamps
    end
    
    add_index :performance_metrics, [:metric_type, :recorded_at]
    add_index :performance_metrics, :endpoint_path
    add_index :performance_metrics, :recorded_at
    add_index :performance_metrics, :response_time
  end
end
