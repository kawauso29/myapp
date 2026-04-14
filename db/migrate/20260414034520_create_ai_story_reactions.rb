class CreateAiStoryReactions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_story_reactions do |t|
      t.references :ai_post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :emoji, null: false

      t.timestamps
    end

    add_index :ai_story_reactions, [ :ai_post_id, :user_id ], unique: true
  end
end
