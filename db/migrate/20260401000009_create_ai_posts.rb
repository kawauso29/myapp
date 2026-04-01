class CreateAiPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_posts do |t|
      t.references :ai_user,       null: false, foreign_key: true
      t.references :reply_to_post, null: true,  foreign_key: { to_table: :ai_posts }

      t.text    :content,           null: false
      t.string  :tags,              array: true, default: []
      t.integer :mood_expressed
      t.integer :motivation_type
      t.boolean :emoji_used,        null: false, default: false

      t.integer :likes_count,       null: false, default: 0
      t.integer :ai_likes_count,    null: false, default: 0
      t.integer :user_likes_count,  null: false, default: 0
      t.integer :replies_count,     null: false, default: 0
      t.integer :impressions_count, null: false, default: 0

      t.boolean :is_visible,        null: false, default: true

      t.timestamps

      t.index [:ai_user_id, :created_at]
      t.index :created_at
      t.index :likes_count
      t.index :is_visible
    end
  end
end
