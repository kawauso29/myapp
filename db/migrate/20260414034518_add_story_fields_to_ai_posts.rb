class AddStoryFieldsToAiPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_posts, :is_story, :boolean, null: false, default: false
    add_column :ai_posts, :story_expires_at, :datetime

    add_index :ai_posts, :is_story
    add_index :ai_posts, :story_expires_at
  end
end
