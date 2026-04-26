require "rails_helper"

RSpec.describe Daily::EmotionRippleEffect do
  describe ".deltas" do
    it "raises stress around a flaming post from a popular connected AI" do
      observer = create(:ai_user)
      influencer = create(:ai_user, followers_count: 80)
      create(:ai_relationship, ai_user: observer, target_ai_user: influencer, relationship_type: :friend, interaction_score: 90)

      post = create(:ai_post, ai_user: influencer, mood_expressed: :negative, created_at: Date.current.beginning_of_day + 12.hours)
      create_list(:post_report, 3, ai_post: post)

      deltas = described_class.deltas(observer)

      expect(deltas[:stress_delta]).to be >= 8
    end

    it "reflects relationship interaction_score in ripple intensity" do
      weak_observer = create(:ai_user)
      strong_observer = create(:ai_user)
      weak_friend = create(:ai_user, followers_count: 80)
      close_friend = create(:ai_user, followers_count: 80)
      create(:ai_relationship, ai_user: weak_observer, target_ai_user: weak_friend, relationship_type: :friend, interaction_score: 10)
      create(:ai_relationship, ai_user: strong_observer, target_ai_user: close_friend, relationship_type: :close_friend, interaction_score: 90)

      weak_post = create(:ai_post, ai_user: weak_friend, mood_expressed: :negative, created_at: Date.current.beginning_of_day + 12.hours)
      close_post = create(:ai_post, ai_user: close_friend, mood_expressed: :negative, created_at: Date.current.beginning_of_day + 12.hours)
      create_list(:post_report, 3, ai_post: weak_post)
      create_list(:post_report, 3, ai_post: close_post)

      weak_deltas = described_class.deltas(weak_observer)
      strong_deltas = described_class.deltas(strong_observer)

      expect(strong_deltas[:stress_delta]).to be > weak_deltas[:stress_delta]
    end

    it "adds concern-driven motivation when close connections are down" do
      ai_user = create(:ai_user)
      close_friend = create(:ai_user)
      create(:ai_relationship, ai_user: ai_user, target_ai_user: close_friend, relationship_type: :close_friend)
      create(:ai_daily_state, ai_user: close_friend, date: Date.current, mood: :very_negative)

      deltas = described_class.deltas(ai_user)

      expect(deltas[:post_motivation_delta]).to be >= 3
      expect(deltas[:stress_delta]).to be >= 2
    end

    it "brightens mood on a mostly positive timeline day" do
      ai_user = create(:ai_user)
      create_list(:ai_post, 8, mood_expressed: :positive, created_at: Date.current.beginning_of_day + 12.hours)

      deltas = described_class.deltas(ai_user)

      expect(deltas[:stress_delta]).to eq(-8)
      expect(deltas[:post_motivation_delta]).to eq(6)
    end
  end
end
