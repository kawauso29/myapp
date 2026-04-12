require "rails_helper"

RSpec.describe AiSns::ObservationCollector do
  describe ".call" do
    it "collects and formats observation metrics" do
      now = Time.zone.parse("2026-04-12 12:00:00")
      posts_scope = instance_double(ActiveRecord::Relation)
      where_chain = double("where_chain")
      root_posts = instance_double(ActiveRecord::Relation)
      replies_scope = instance_double(ActiveRecord::Relation)
      active_posters_scope = instance_double(ActiveRecord::Relation)

      allow(AiPost).to receive(:where).and_return(posts_scope)
      allow(posts_scope).to receive(:where).with(reply_to_post_id: nil).and_return(root_posts)
      allow(posts_scope).to receive(:where).with(no_args).and_return(where_chain)
      allow(where_chain).to receive(:not).with(reply_to_post_id: nil).and_return(replies_scope)
      allow(posts_scope).to receive(:select).with(:ai_user_id).and_return(active_posters_scope)
      allow(active_posters_scope).to receive(:distinct).and_return(active_posters_scope)
      allow(active_posters_scope).to receive(:count).and_return(3)

      allow(root_posts).to receive(:count).and_return(12)
      allow(root_posts).to receive(:sum).with(:likes_count).and_return(30)
      allow(root_posts).to receive(:empty?).and_return(false)
      allow(replies_scope).to receive(:count).and_return(6)

      allow(AiUser).to receive(:count).and_return(20)
      allow(AiUser).to receive_message_chain(:active, :count).and_return(15)
      allow(AiDmThread).to receive(:where).and_return(double(count: 5))
      allow(PostReport).to receive_message_chain(:pending, :count).and_return(2)
      allow(SolidQueue::FailedExecution).to receive(:count).and_return(1)
      allow(SolidQueue::RecurringTask).to receive(:count).and_return(9)

      result = described_class.call(now: now)

      expect(result[:generated_at]).to eq(now.iso8601)
      expect(result.dig(:totals, :posts_24h)).to eq(12)
      expect(result.dig(:engagement, :avg_likes_per_post_24h)).to eq(2.5)
      expect(result.dig(:operations, :pending_reports)).to eq(2)
    end
  end
end
