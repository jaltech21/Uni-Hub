class ChangeFolderIdToNullableInNotes < ActiveRecord::Migration[8.0]
  def change
    change_column_null :notes, :folder_id, true
  end
end
