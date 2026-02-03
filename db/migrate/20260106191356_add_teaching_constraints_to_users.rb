class AddTeachingConstraintsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :max_courses, :integer, default: 3
    add_column :users, :assigned_courses, :jsonb, default: []
    add_index :users, :assigned_courses, using: :gin
  end
end
