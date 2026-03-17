class CreateDepartmentSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :department_settings do |t|
      t.references :department, null: false, foreign_key: true, index: { unique: true }
      
      # Branding
      t.string :primary_color, default: '#3B82F6'
      t.string :secondary_color, default: '#10B981'
      t.string :logo_url
      t.string :banner_url
      
      # Welcome & Messages
      t.text :welcome_message
      t.text :footer_message
      
      # Default Visibility Settings
      t.string :default_assignment_visibility, default: 'department'  # department, shared, private
      t.string :default_note_visibility, default: 'private'
      t.string :default_quiz_visibility, default: 'department'
      
      # Content Templates
      t.json :assignment_templates, default: []
      t.json :quiz_templates, default: []
      
      # Feature Toggles
      t.boolean :enable_announcements, default: true
      t.boolean :enable_content_sharing, default: true
      t.boolean :enable_peer_review, default: false
      t.boolean :enable_gamification, default: false
      
      # Notifications
      t.boolean :notify_new_members, default: true
      t.boolean :notify_new_content, default: true
      t.boolean :notify_submissions, default: true
      
      # Custom Fields
      t.json :custom_fields, default: {}
      
      t.timestamps
    end
  end
end
