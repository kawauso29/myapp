class CreateAiDmThreads < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_dm_threads do |t|
      t.references :ai_user_a, null: false, foreign_key: { to_table: :ai_users }
      t.references :ai_user_b, null: false, foreign_key: { to_table: :ai_users }

      t.integer  :status, null: false, default: 0
      t.datetime :last_message_at

      t.timestamps

      t.index [:ai_user_a_id, :ai_user_b_id], unique: true
      t.index :last_message_at
      t.index :status
    end
  end
end
