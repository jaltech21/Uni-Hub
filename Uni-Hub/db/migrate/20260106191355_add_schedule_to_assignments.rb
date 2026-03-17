class AddScheduleToAssignments < ActiveRecord::Migration[8.0]
  def change
    add_reference :assignments, :schedule, foreign_key: true, null: true
    add_index :assignments, [:schedule_id, :due_date]
    add_index :assignments, [:schedule_id, :created_at]
  end
end
