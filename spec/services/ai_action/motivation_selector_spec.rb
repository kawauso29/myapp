require "rails_helper"

RSpec.describe AiAction::MotivationSelector do
  let(:ai_user) { create(:ai_user) }
  let(:daily_state) do
    create(:ai_daily_state, ai_user: ai_user, mood: :neutral, busyness: :normal_busyness,
                             today_events: [], stress_level: 30, social_battery: 60,
                             concentration: :normal_concentration, appetite: :normal_appetite,
                             morning_mood: :ok_morning, going_out: false, hourly_states: [])
  end

  subject(:selector) { described_class.new(ai_user, daily_state) }

  describe "#select" do
    context "on a regular day with no events" do
      it "returns a valid motivation" do
        result = selector.select
        expect(result).to have_key(:primary)
        expect(described_class::MOTIVATIONS).to include(result[:primary])
      end
    end

    context "on an event day" do
      before { daily_state.today_events = [ "cherry_blossom" ] }

      it "evaluates candidates with sharing boost applied" do
        candidates = selector.send(:evaluate_candidates)
        # sharing should be at least 25 (event day boost)
        expect(candidates[:sharing]).to be >= 25
      end

      it "evaluates candidates with self_expressing boost applied" do
        candidates = selector.send(:evaluate_candidates)
        # self_expressing should be at least 15 (event day boost)
        expect(candidates[:self_expressing]).to be >= 15
      end
    end

    context "with positive mood and an event" do
      before do
        daily_state.today_events = [ "valentine" ]
        daily_state.mood = "positive"
      end

      it "gives sharing a cumulative boost from both mood and event" do
        candidates = selector.send(:evaluate_candidates)
        # base from positive mood: 55, plus event boost: 25 => 80
        expect(candidates[:sharing]).to eq(80)
      end
    end

    context "on a regular day without events" do
      it "does not add event boost to sharing" do
        # mood is neutral, so sharing is not in candidates without event boost
        candidates = selector.send(:evaluate_candidates)
        expect(candidates[:sharing].to_i).to eq(0)
      end
    end
  end
end
