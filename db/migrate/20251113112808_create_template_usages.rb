class CreateTemplateUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :template_usages do |t|
      t.references :content_template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :used_at
      t.string :context

      t.timestamps
    end
  end
end
