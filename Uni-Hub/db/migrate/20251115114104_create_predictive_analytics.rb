class CreatePredictiveAnalytics < ActiveRecord::Migration[8.0]
  def change
    create_table :predictive_analytics do |t|
      t.string :prediction_type
      t.string :target_entity_type
      t.integer :target_entity_id
      t.decimal :prediction_value
      t.decimal :confidence_score
      t.string :model_version
      t.json :features
      t.timestamp :prediction_date
      t.references :campus, null: true, foreign_key: { to_table: :campuses }
      t.references :department, null: true, foreign_key: true

      t.timestamps
    end
    
    add_index :predictive_analytics, [:prediction_type, :prediction_date]
    add_index :predictive_analytics, [:target_entity_type, :target_entity_id]
    add_index :predictive_analytics, :confidence_score
    add_index :predictive_analytics, :prediction_date
  end
end
