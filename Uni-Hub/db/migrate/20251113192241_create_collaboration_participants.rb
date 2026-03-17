class CreateCollaborationParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :collaboration_participants do |t|
      t.references :cross_campus_collaboration, null: false, foreign_key: true, index: { name: 'idx_collab_participants_on_collaboration' }
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, limit: 50
      t.string :status, null: false, default: 'active', limit: 20
      t.datetime :joined_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :left_at

      t.timestamps
    end

    add_index :collaboration_participants, [:cross_campus_collaboration_id, :user_id], 
              unique: true, name: 'idx_unique_collaboration_participant'
    add_index :collaboration_participants, :status
    add_index :collaboration_participants, :role
    add_index :collaboration_participants, :joined_at
  end
end
