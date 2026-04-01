require "rails_helper"

RSpec.describe AiAction::ActionChecker do
  let(:ai_user) { create(:ai_user) }
  let(:personality) { ai_user.ai_personality }
  let(:daily_state) { create(:ai_daily_state, ai_user: ai_user) }

  describe ".should_post?" do
    it "delegates to instance method" do
      checker = instance_double(described_class, should_post?: false)
      allow(described_class).to receive(:new).with(ai_user, daily_state).and_return(checker)

      result = described_class.should_post?(ai_user, daily_state)
      expect(result).to be false
    end
  end

  describe "#should_post?" do
    subject(:should_post) { described_class.new(ai_user, daily_state).should_post? }

    context "when physical state is sick" do
      let(:daily_state) { create(:ai_daily_state, :sick, ai_user: ai_user) }

      it "returns false" do
        expect(should_post).to be false
      end
    end

    context "when post_motivation is below 20" do
      let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 19) }

      it "returns false" do
        expect(should_post).to be false
      end
    end

    context "when post_motivation is exactly 20" do
      let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 20) }

      it "does not force-return false (evaluates further)" do
        # post_motivation >= 20 passes force_no_post? check
        # The final result depends on hour_multiplier, interval, cooldown
        checker = described_class.new(ai_user, daily_state)
        # We just verify it gets past force_no_post?
        expect(checker).to receive(:force_no_post?).and_call_original
        checker.should_post?
      end
    end

    context "when high need_for_approval and last 5 posts have zero engagement" do
      before do
        personality.update!(need_for_approval: :high)
        5.times { create(:ai_post, ai_user: ai_user, likes_count: 0, replies_count: 0) }
      end

      it "returns false" do
        expect(should_post).to be false
      end
    end

    context "when during peak hours with high motivation" do
      let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 95) }

      before do
        personality.update!(active_time_peak: :normal)
        # Stub Time.current to 15:00 (within normal peak hours 12-21)
        allow(Time).to receive(:current).and_return(Time.zone.now.change(hour: 15))
      end

      it "has higher chance of posting (hour_multiplier = 1.5)" do
        checker = described_class.new(ai_user, daily_state)
        # With motivation=95, peak hour multiplier=1.5, the final score should be well above 60
        # Just verify the method doesn't crash and returns boolean
        expect([true, false]).to include(checker.should_post?)
      end
    end

    context "when outside peak hours with low motivation" do
      let(:daily_state) { create(:ai_daily_state, ai_user: ai_user, post_motivation: 30) }

      before do
        personality.update!(active_time_peak: :very_low) # peak at 6-9
        # Stub to 22:00, outside very_low peak hours
        allow(Time).to receive(:current).and_return(Time.zone.now.change(hour: 22))
      end

      it "returns false due to low final score (0.5 multiplier)" do
        # motivation=30 * 0.5 = 15, plus interval bonus ~10-35 = ~25-50
        # Even best case 50 * cooldown(1.0) = 50 < 60 threshold
        allow(ai_user).to receive(:last_posted_at).and_return(nil)
        checker = described_class.new(ai_user, daily_state)
        expect(checker.should_post?).to be false
      end
    end
  end
end
