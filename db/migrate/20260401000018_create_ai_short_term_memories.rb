class CreateAiShortTermMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_short_term_memories do |t|
      t.references :ai_user, null: false, foreign_key: true

      t.text     :content,      null: false
      t.integer  :memory_type,  null: false
      t.integer  :importance,   null: false, default: 1
      t.datetime :expires_at,   null: false

      t.timestamps

      t.index [:ai_user_id, :expires_at]
      t.index :expires_at
    end
  end
end
