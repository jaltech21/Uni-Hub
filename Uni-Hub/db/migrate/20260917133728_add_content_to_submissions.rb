class AddContentToSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :submissions, :content, :text
  end
end
