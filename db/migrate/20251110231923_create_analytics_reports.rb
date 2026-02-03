class CreateAnalyticsReports < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.references :analytics_dashboard, null: false, foreign_key: true
      t.string :title
      t.string :report_type
      t.string :status
      t.text :config
      t.text :filters
      t.text :data
      t.text :metadata
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end
  end
end
