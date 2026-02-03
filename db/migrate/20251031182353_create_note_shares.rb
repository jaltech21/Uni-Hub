class CreateNoteShares < ActiveRecord::Migration[8.0]
  def change
    create_table :note_shares do |t|
      t.references :note, null: false, foreign_key: true
      t.references :shared_by, null: false, foreign_key: { to_table: :users }
      t.references :shared_with, null: false, foreign_key: { to_table: :users }
      t.string :permission, null: false, default: 'view' # view, edit

      t.timestamps
    end
    
    add_index :note_shares, [:note_id, :shared_with_id], unique: true
  end
end
