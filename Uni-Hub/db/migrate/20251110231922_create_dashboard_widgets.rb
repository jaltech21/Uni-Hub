class CreateDashboardWidgets < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboard_widgets do |t|
      t.references :analytics_dashboard, null: false, foreign_key: true
      t.string :widget_type
      t.string :title
      t.text :description
      t.integer :position_x
      t.integer :position_y
      t.integer :width
      t.integer :height
      t.text :config
      t.text :data_sources
      t.text :filter_config
      t.boolean :active

      t.timestamps
    end
  end
end
