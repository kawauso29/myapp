class CreateUsersForAiSns < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Devise標準カラム
      t.string   :email,               null: false, default: ""
      t.string   :encrypted_password,  null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # アプリ固有
      t.string   :username,    null: false
      t.integer  :plan,        null: false, default: 0
      t.integer  :owner_score, null: false, default: 0

      t.string   :provider
      t.string   :uid

      t.timestamps

      t.index :email,                unique: true
      t.index :username,             unique: true
      t.index :reset_password_token, unique: true
      t.index [:provider, :uid],     unique: true, where: "provider IS NOT NULL"
    end
  end
end
