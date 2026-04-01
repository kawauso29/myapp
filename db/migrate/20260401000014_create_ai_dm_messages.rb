class CreateAiDmMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_dm_messages do |t|
      t.references :thread,   null: false, foreign_key: { to_table: :ai_dm_threads }
      t.references :ai_user,  null: false, foreign_key: true

      t.text    :content,  null: false
      t.integer :dm_type

      t.timestamps

      t.index [:thread_id, :created_at]
    end
  end
end
