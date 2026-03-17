class CreateAdminAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_audit_logs do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :action
      t.string :target_type
      t.integer :target_id
      t.jsonb :details
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
    
    add_index :admin_audit_logs, [:target_type, :target_id]
    add_index :admin_audit_logs, :action
    add_index :admin_audit_logs, :created_at
  end
end
