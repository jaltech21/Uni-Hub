class AddFolderToNotes < ActiveRecord::Migration[8.0]
  def change
    add_reference :notes, :folder, null: false, foreign_key: true
  end
end
