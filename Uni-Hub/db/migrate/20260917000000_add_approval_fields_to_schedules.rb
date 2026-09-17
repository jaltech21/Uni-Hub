class AddApprovalFieldsToSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :schedules, :approved_at, :datetime
    add_column :schedules, :cancelled_at, :datetime
    add_column :schedules, :approved_by_id, :bigint, null: true
    add_column :schedules, :cancelled_by_id, :bigint, null: true
    add_column :schedules, :cancellation_reason, :string
    add_index :schedules, :approved_by_id
    add_index :schedules, :cancelled_by_id
  end
end