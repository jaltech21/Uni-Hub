class EnhanceSchedulesTable < ActiveRecord::Migration[8.0]
  def change
    add_column :schedules, :course, :string
    add_column :schedules, :day_of_week, :integer
    add_column :schedules, :room, :string
    add_column :schedules, :instructor_id, :integer
    add_column :schedules, :recurring, :boolean, default: true
    add_column :schedules, :color, :string, default: '#3B82F6'
    
    add_index :schedules, :instructor_id
    add_index :schedules, :day_of_week
    add_index :schedules, [:day_of_week, :start_time]
  end
end
