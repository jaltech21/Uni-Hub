class CreateTemplateFavorites < ActiveRecord::Migration[8.0]
  def change
    create_table :template_favorites do |t|
      t.references :content_template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :favorited_at

      t.timestamps
    end
  end
end
