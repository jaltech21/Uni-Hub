class CreateCrossCampusCollaborations < ActiveRecord::Migration[8.0]
  def change
    create_table :cross_campus_collaborations do |t|
      t.string :name, null: false
      t.text :description
      t.string :collaboration_type, null: false # research, academic_program, student_exchange, resource_sharing, joint_degree
      t.references :initiating_campus, null: false, foreign_key: { to_table: :campuses }
      t.json :participating_campuses # Array of campus IDs
      t.date :start_date
      t.date :end_date
      t.string :status, default: 'planning' # planning, active, completed, suspended, cancelled
      t.references :coordinator, null: false, foreign_key: { to_table: :users }
      
      # Collaboration details
      t.decimal :budget_allocated, precision: 12, scale: 2
      t.decimal :budget_spent, precision: 12, scale: 2, default: 0
      t.text :objectives
      t.text :expected_outcomes
      t.json :milestones
      t.json :resources_shared
      t.integer :students_involved, default: 0
      t.integer :faculty_involved, default: 0
      t.text :success_metrics
      t.text :challenges_faced
      t.decimal :completion_percentage, precision: 5, scale: 2, default: 0
      t.json :approval_workflow
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :cross_campus_collaborations, :collaboration_type, name: 'idx_cross_campus_collab_type'
    add_index :cross_campus_collaborations, :status, name: 'idx_cross_campus_collab_status'
    add_index :cross_campus_collaborations, :coordinator_id, name: 'idx_cross_campus_collab_coordinator'
    add_index :cross_campus_collaborations, [:start_date, :end_date], name: 'idx_cross_campus_collab_dates'
    add_index :cross_campus_collaborations, :completion_percentage, name: 'idx_cross_campus_collab_completion'
  end
end
