class AddBlacklistFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :blacklisted, :boolean, default: false
    add_column :users, :blacklisted_at, :datetime
    add_reference :users, :blacklisted_by, foreign_key: { to_table: :users }
    add_column :users, :unblacklisted_at, :datetime
    add_reference :users, :unblacklisted_by, foreign_key: { to_table: :users }
    add_column :users, :blacklist_reason, :text
  end
end
