class CreateAnalyticsDashboards < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_dashboards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.string :title
      t.string :dashboard_type
      t.text :layout_config
      t.text :filter_config
      t.text :permissions_config
      t.boolean :active

      t.timestamps
    end
  end
end
