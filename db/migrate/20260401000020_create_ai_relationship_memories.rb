class CreateAiRelationshipMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_relationship_memories do |t|
      t.references :ai_user,        null: false, foreign_key: true
      t.references :target_ai_user, null: false, foreign_key: { to_table: :ai_users }

      t.text :summary,       null: false
      t.date :last_updated_on

      t.timestamps

      t.index [:ai_user_id, :target_ai_user_id], unique: true
    end
  end
end
