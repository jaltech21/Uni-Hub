class CreateContentTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :content_templates do |t|
      t.string :name
      t.text :description
      t.string :template_type
      t.text :content
      t.json :metadata
      t.string :visibility
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :department, null: true, foreign_key: true
      t.string :category
      t.text :tags
      t.boolean :is_featured
      t.integer :usage_count
      t.string :version
      t.references :parent_template, null: true, foreign_key: { to_table: :content_templates }
      t.string :status

      t.timestamps
    end
  end
end
