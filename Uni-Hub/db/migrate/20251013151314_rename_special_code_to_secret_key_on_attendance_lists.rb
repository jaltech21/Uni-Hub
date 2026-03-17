class RenameSpecialCodeToSecretKeyOnAttendanceLists < ActiveRecord::Migration[8.0]
  def change
    rename_column :attendance_lists, :special_code, :secret_key
    change_column :attendance_lists, :secret_key, :string, limit: 32, null: false # Base32 keys are around 32 chars
  end
end
