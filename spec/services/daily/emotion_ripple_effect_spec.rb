require "rails_helper"

RSpec.describe Daily::EmotionRippleEffect do
  describe ".deltas" do
    it "raises stress around a flaming post from a popular connected AI" do
      observer = create(:ai_user)
      influencer = create(:ai_user, followers_count: 80)
      create(:ai_relationship, ai_user: observer, target_ai_user: influencer, relationship_type: :friend)

      post = create(:ai_post, ai_user: influencer, mood_expressed: :negative, created_at: Date.current.beginning_of_day + 12.hours)
      create_list(:post_report, 3, ai_post: post)

      deltas = described_class.deltas(observer)

      expect(deltas[:stress_delta]).to be >= 12
    end

    it "adds concern-driven motivation when close connections are down" do
      ai_user = create(:ai_user)
      close_friend = create(:ai_user)
      create(:ai_relationship, ai_user: ai_user, target_ai_user: close_friend, relationship_type: :close_friend)
      create(:ai_daily_state, ai_user: close_friend, date: Date.current, mood: :very_negative)

      deltas = described_class.deltas(ai_user)

      expect(deltas[:post_motivation_delta]).to be >= 6
      expect(deltas[:stress_delta]).to be >= 4
    end

    it "brightens mood on a mostly positive timeline day" do
      ai_user = create(:ai_user)
      create_list(:ai_post, 8, mood_expressed: :positive, created_at: Date.current.beginning_of_day + 12.hours)

      deltas = described_class.deltas(ai_user)

      expect(deltas[:stress_delta]).to eq(-8)
      expect(deltas[:post_motivation_delta]).to eq(6)
    end

    it "scales concern effect higher when interaction_score is high" do
      ai_user = create(:ai_user)
      close_friend = create(:ai_user)
      # interaction_score=100 → coefficient = 1.0 + 100/200 = 1.5
      create(:ai_relationship, ai_user: ai_user, target_ai_user: close_friend,
             relationship_type: :close_friend, interaction_score: 100)
      create(:ai_daily_state, ai_user: close_friend, date: Date.current, mood: :very_negative)

      deltas = described_class.deltas(ai_user)

      # motivation_delta = (1.5 * 6).round = 9
      expect(deltas[:post_motivation_delta]).to eq(9)
    end

    it "applies lower ripple coefficient for friend than close_friend" do
      ai_user = create(:ai_user)
      acquaintance = create(:ai_user)
      create(:ai_relationship, ai_user: ai_user, target_ai_user: acquaintance, relationship_type: :friend)
      create(:ai_daily_state, ai_user: acquaintance, date: Date.current, mood: :very_negative)

      deltas = described_class.deltas(ai_user)

      # friend coefficient = 0.7 → motivation_delta = (0.7 * 6).round = 4
      expect(deltas[:post_motivation_delta]).to eq(4)
    end
  end
end
