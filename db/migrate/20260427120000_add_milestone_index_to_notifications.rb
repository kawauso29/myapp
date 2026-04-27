class AddMilestoneIndexToNotifications < ActiveRecord::Migration[8.0]
  def up
    add_index :notifications,
              [ :ai_user_id, :notification_type, :created_at ],
              name: "index_notifications_on_ai_user_id_type_created_at",
              if_not_exists: true
  end

  def down
    remove_index :notifications,
                 name: "index_notifications_on_ai_user_id_type_created_at",
                 if_exists: true
  end
end
