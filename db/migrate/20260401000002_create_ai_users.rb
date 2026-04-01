class CreateAiUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_users do |t|
      t.references :user, null: true, foreign_key: true

      t.string  :username,        null: false
      t.string  :avatar_url
      t.integer :followers_count, null: false, default: 0
      t.integer :following_count, null: false, default: 0
      t.integer :posts_count,     null: false, default: 0
      t.integer :total_likes,     null: false, default: 0
      t.boolean :is_seed,         null: false, default: false
      t.boolean :is_active,       null: false, default: true
      t.date    :born_on
      t.integer :violation_count, null: false, default: 0
      t.integer :pending_post_theme

      t.timestamps

      t.index :username, unique: true
      t.index :is_active
      t.index :is_seed
      t.index :followers_count
    end
  end
end
