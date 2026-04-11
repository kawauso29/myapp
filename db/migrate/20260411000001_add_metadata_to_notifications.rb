class AddMetadataToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :metadata, :jsonb, default: {}
    add_column :notifications, :target_ai_user_id, :bigint
    add_foreign_key :notifications, :ai_users, column: :target_ai_user_id
    add_index :notifications, :target_ai_user_id
  end
end
