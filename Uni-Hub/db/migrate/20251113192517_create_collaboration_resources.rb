class CreateCollaborationResources < ActiveRecord::Migration[8.0]
  def change
    create_table :collaboration_resources do |t|
      t.references :cross_campus_collaboration, null: false, foreign_key: true, index: { name: 'idx_resources_on_collaboration' }
      t.string :resource_type, null: false, limit: 50
      t.string :name, null: false, limit: 255
      t.text :description
      t.string :url, limit: 500
      t.boolean :is_public, default: false
      t.decimal :file_size_mb, precision: 10, scale: 2
      t.string :access_level, limit: 30, default: 'collaboration_only'
      t.json :metadata

      t.timestamps
    end

    add_index :collaboration_resources, :resource_type
    add_index :collaboration_resources, :is_public
    add_index :collaboration_resources, :access_level
    add_index :collaboration_resources, [:resource_type, :is_public], name: 'idx_resources_type_public'
  end
end
