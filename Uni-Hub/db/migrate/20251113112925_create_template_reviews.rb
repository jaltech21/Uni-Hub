class CreateTemplateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :template_reviews do |t|
      t.references :content_template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :rating
      t.text :review_text
      t.integer :helpful_votes

      t.timestamps
    end
  end
end
