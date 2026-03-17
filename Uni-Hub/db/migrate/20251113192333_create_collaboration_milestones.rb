class CreateCollaborationMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :collaboration_milestones do |t|
      t.references :cross_campus_collaboration, null: false, foreign_key: true, index: { name: 'idx_milestones_on_collaboration' }
      t.string :title, null: false, limit: 255
      t.text :description
      t.date :due_date, null: false
      t.string :status, null: false, default: 'pending', limit: 30
      t.datetime :completed_at
      t.integer :priority, default: 1
      t.decimal :completion_percentage, precision: 5, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :collaboration_milestones, :status
    add_index :collaboration_milestones, :due_date
    add_index :collaboration_milestones, [:status, :due_date], name: 'idx_milestones_status_due_date'
    add_index :collaboration_milestones, :priority
  end
end
