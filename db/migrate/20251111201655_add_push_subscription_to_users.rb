class AddPushSubscriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :push_subscription, :json
    add_column :users, :notification_preferences, :json
  end
end
