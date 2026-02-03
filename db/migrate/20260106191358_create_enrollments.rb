class CreateEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :schedule, null: false, foreign_key: true
      t.datetime :enrollment_date, default: -> { 'CURRENT_TIMESTAMP' }
      t.string :status, default: 'active'
      t.string :academic_year
      t.string :semester

      t.timestamps
    end
    
    add_index :enrollments, [:user_id, :schedule_id], unique: true
    add_index :enrollments, [:user_id, :status]
    add_index :enrollments, [:schedule_id, :status]
    add_index :enrollments, [:academic_year, :semester]
  end
end
