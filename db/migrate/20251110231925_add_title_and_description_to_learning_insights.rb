class AddTitleAndDescriptionToLearningInsights < ActiveRecord::Migration[8.0]
  def change
    add_column :learning_insights, :title, :text
    add_column :learning_insights, :description, :text
  end
end
