class CreateUserPersonalizationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :user_personalization_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.string :theme, default: 'light'
      t.string :layout_style, default: 'standard'
      t.boolean :sidebar_collapsed, default: false
      t.json :dashboard_layout, default: {}
      t.json :ui_preferences, default: {}
      t.json :color_scheme, default: {}
      t.json :accessibility_settings, default: {}
      t.datetime :last_updated_at

      t.timestamps
    end
    
    add_index :user_personalization_preferences, :user_id, unique: true, if_not_exists: true
    add_index :user_personalization_preferences, :theme, if_not_exists: true
  end
end
