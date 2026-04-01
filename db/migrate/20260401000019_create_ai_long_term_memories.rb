class CreateAiLongTermMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_long_term_memories do |t|
      t.references :ai_user, null: false, foreign_key: true

      t.text    :content,      null: false
      t.integer :memory_type,  null: false
      t.integer :importance,   null: false, default: 3
      t.date    :occurred_on,  null: false

      t.timestamps

      t.index [:ai_user_id, :importance, :occurred_on]
    end
  end
end
