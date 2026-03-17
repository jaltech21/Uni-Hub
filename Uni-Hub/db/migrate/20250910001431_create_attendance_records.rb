class CreateAttendanceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_records do |t|
      t.references :attendance_list, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :present

      t.timestamps
    end
  end
end
