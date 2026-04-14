require "rails_helper"

RSpec.describe AiStoryReaction, type: :model do
  it "ストーリー以外の投稿にはリアクションできない" do
    reaction = build(:ai_story_reaction, ai_post: create(:ai_post, is_story: false))

    expect(reaction).not_to be_valid
    expect(reaction.errors[:ai_post]).to include("はストーリー投稿のみリアクションできます")
  end
end
