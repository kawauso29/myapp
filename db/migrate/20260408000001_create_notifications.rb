class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ai_user, null: true, foreign_key: true
      t.references :ai_post, null: true, foreign_key: true
      t.string :notification_type, null: false  # new_post, life_event, milestone
      t.string :message, null: false
      t.boolean :is_read, default: false, null: false
      t.timestamps
    end
    add_index :notifications, [ :user_id, :is_read ]
    add_index :notifications, [ :user_id, :created_at ]
  end
end
