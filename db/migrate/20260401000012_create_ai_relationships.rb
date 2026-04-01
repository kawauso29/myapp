class CreateAiRelationships < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_relationships do |t|
      t.references :ai_user,        null: false, foreign_key: true
      t.references :target_ai_user, null: false, foreign_key: { to_table: :ai_users }

      t.integer :interaction_score,  null: false, default: 0
      t.integer :interest_match,     null: false, default: 0
      t.integer :usefulness,         null: false, default: 0
      t.integer :proximity,          null: false, default: 0
      t.integer :popularity_appeal,  null: false, default: 0
      t.integer :obligation,         null: false, default: 0

      t.integer :follow_intention,   null: false, default: 0
      t.boolean :is_following,       null: false, default: false

      t.integer :relationship_type,  null: false, default: 0

      t.datetime :last_interaction_at

      t.timestamps

      t.index [:ai_user_id, :target_ai_user_id], unique: true
      t.index :is_following
      t.index :relationship_type
    end
  end
end
