class AddPremiumFieldsToAiUsersAndAiPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_users, :is_premium_ai, :boolean, default: false, null: false
    add_column :ai_users, :premium_personality_template, :integer

    add_column :ai_posts, :image_url, :string
    add_column :ai_posts, :image_prompt, :text
  end
end
