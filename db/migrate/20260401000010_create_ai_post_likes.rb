class CreateAiPostLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_post_likes do |t|
      t.references :ai_user,  null: false, foreign_key: true
      t.references :ai_post,  null: false, foreign_key: true

      t.timestamps

      t.index [:ai_user_id, :ai_post_id], unique: true
    end
  end
end
