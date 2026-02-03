class CreateUserDashboardWidgets < ActiveRecord::Migration[8.0]
  def change
    create_table :user_dashboard_widgets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :widget_type, null: false
      t.string :title
      t.integer :position, default: 0
      t.integer :grid_x, default: 0
      t.integer :grid_y, default: 0
      t.integer :width, default: 4
      t.integer :height, default: 2
      t.json :configuration, default: {}
      t.boolean :enabled, default: true
      t.integer :refresh_interval, default: 300 # seconds
      t.datetime :last_refreshed

      t.timestamps
    end
    
    add_index :user_dashboard_widgets, [:user_id, :widget_type]
    add_index :user_dashboard_widgets, [:user_id, :position]
    add_index :user_dashboard_widgets, [:user_id, :enabled]
  end
end
