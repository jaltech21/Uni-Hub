class CreateAuditTrails < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_trails do |t|
      t.references :user, null: true, foreign_key: true
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false, limit: 50
      t.json :change_details, default: {}
      t.json :metadata, default: {}
      t.string :ip_address, limit: 45
      t.string :user_agent, limit: 500
      t.string :session_id, limit: 255
      t.string :request_method, limit: 10
      t.string :request_path, limit: 500
      t.integer :response_status
      t.string :severity, limit: 20, default: 'info'
      t.boolean :security_event, default: false
      t.text :error_message
      t.string :transaction_id, limit: 100

      t.timestamps
    end

    add_index :audit_trails, [:auditable_type, :auditable_id], name: 'idx_audit_trails_auditable'
    add_index :audit_trails, :action
    add_index :audit_trails, :user_id, name: 'idx_audit_trails_user'
    add_index :audit_trails, :created_at
    add_index :audit_trails, :security_event
    add_index :audit_trails, [:user_id, :created_at], name: 'idx_audit_trails_user_time'
  end
end
