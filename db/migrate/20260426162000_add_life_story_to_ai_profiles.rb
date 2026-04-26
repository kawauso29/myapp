class AddLifeStoryToAiProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_profiles, :life_story, :text
    add_column :ai_profiles, :life_story_generated_at, :datetime
  end
end
