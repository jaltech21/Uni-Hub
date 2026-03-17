class CreateAttendanceLists < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_lists do |t|
      t.string :title
      t.text :description
      t.date :date
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_column :attendance_lists, :special_code, :string, limit: 6
  end
end
