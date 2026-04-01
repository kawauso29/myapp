class CreateUserAiLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :user_ai_likes do |t|
      t.references :user,    null: false, foreign_key: true
      t.references :ai_post, null: false, foreign_key: true

      t.timestamps

      t.index [:user_id, :ai_post_id], unique: true
    end
  end
end
