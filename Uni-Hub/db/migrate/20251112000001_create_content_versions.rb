class CreateContentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :content_versions do |t|
      # Polymorphic association to versionable content
      t.references :versionable, null: false, polymorphic: true, index: true
      
      # User who created this version
      t.references :user, null: false, foreign_key: true, index: true
      
      # Version hierarchy
      t.references :parent_version, null: true, foreign_key: { to_table: :content_versions }, index: true
      
      # Version identification
      t.integer :version_number, null: false
      t.integer :patch_number, default: 0
      t.string :branch_name, null: true
      t.string :version_tag, null: true
      
      # Content data (JSON)
      t.json :content_data, null: false
      t.json :metadata, default: {}
      t.json :diff_data, default: {}
      
      # Version status and type
      t.integer :status, default: 0, null: false # draft: 0, published: 1, archived: 2
      t.integer :change_type, default: 0, null: false # minor: 0, major: 1, patch: 2, breaking: 3, content: 4, structure: 5, metadata: 6
      
      # Change description
      t.string :change_summary, limit: 500, null: false
      t.text :change_description
      
      # Content integrity
      t.string :content_hash, null: false, index: true
      t.bigint :content_size, default: 0
      
      # Publishing info
      t.timestamp :published_at
      t.references :published_by, null: true, foreign_key: { to_table: :users }
      
      # Approval workflow
      t.integer :approval_status, default: 0 # pending: 0, approved: 1, rejected: 2, review_requested: 3
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.timestamp :approved_at
      t.text :approval_notes
      
      # Analytics
      t.integer :views_count, default: 0
      t.integer :downloads_count, default: 0
      t.timestamp :last_accessed_at
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :content_versions, [:versionable_type, :versionable_id, :version_number], 
              unique: true, name: 'idx_content_versions_unique_version'
    add_index :content_versions, [:versionable_type, :versionable_id, :status], 
              name: 'idx_content_versions_status'
    add_index :content_versions, [:user_id, :created_at], name: 'idx_content_versions_user_timeline'
    add_index :content_versions, [:status, :published_at], name: 'idx_content_versions_published'
    add_index :content_versions, :branch_name, where: "branch_name IS NOT NULL"
    
    # Partial index for current published versions
    add_index :content_versions, [:versionable_type, :versionable_id], 
              where: "status = 1", name: 'idx_content_versions_current_published'
  end
end