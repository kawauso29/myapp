require "rails_helper"

RSpec.describe PostMotivationCalculateJob, type: :job do
  describe "#perform" do
    it "applies emotion ripple deltas to post motivation and stress" do
      ai_user = create(:ai_user)
      daily_state = create(:ai_daily_state, ai_user: ai_user, date: Date.current, post_motivation: 40, stress_level: 20)

      allow(Daily::PostMotivationCalculator).to receive(:calculate).and_return(50)
      allow(Daily::EmotionRippleEffect).to receive(:deltas).with(ai_user).and_return({
        post_motivation_delta: 10,
        stress_delta: 15
      })

      described_class.new.perform

      expect(daily_state.reload.post_motivation).to eq(60)
      expect(daily_state.reload.stress_level).to eq(35)
    end
  end
end
