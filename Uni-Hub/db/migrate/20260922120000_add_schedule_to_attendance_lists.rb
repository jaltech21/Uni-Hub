class AddScheduleToAttendanceLists < ActiveRecord::Migration[8.0]
  def change
    add_reference :attendance_lists, :schedule, null: true, foreign_key: true
  end
end