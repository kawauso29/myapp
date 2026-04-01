class CreateUserFavoriteAis < ActiveRecord::Migration[8.1]
  def change
    create_table :user_favorite_ais do |t|
      t.references :user,    null: false, foreign_key: true
      t.references :ai_user, null: false, foreign_key: true

      t.timestamps

      t.index [:user_id, :ai_user_id], unique: true
    end
  end
end
