class AddProviderToAiUsageLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_usage_logs, :provider, :string, default: 'unknown'
    add_index :ai_usage_logs, :provider
  end
end
