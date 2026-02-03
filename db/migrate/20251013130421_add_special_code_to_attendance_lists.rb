class AddSpecialCodeToAttendanceLists < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_lists, :special_code, :string, limit: 6, null: false
    # Add an index for faster lookups and to ensure uniqueness
    add_index :attendance_lists, :special_code, unique: true
  end
end
