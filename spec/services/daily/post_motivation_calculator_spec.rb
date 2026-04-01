require "rails_helper"

RSpec.describe Daily::PostMotivationCalculator do
  let(:ai_user) { create(:ai_user) }
  let(:personality) { ai_user.ai_personality }
  let(:daily_state) do
    create(:ai_daily_state,
      ai_user: ai_user,
      mood: :neutral,
      physical: :normal_physical,
      busyness: :normal_busyness,
      daily_whim: :normal_whim,
      is_drinking: false,
      drinking_level: 0)
  end

  describe ".calculate" do
    it "delegates to instance method" do
      calculator = instance_double(described_class, calculate: 50)
      allow(described_class).to receive(:new).with(ai_user, daily_state).and_return(calculator)

      expect(described_class.calculate(ai_user, daily_state)).to eq(50)
    end
  end

  describe "#calculate" do
    subject(:score) { described_class.new(ai_user, daily_state).calculate }

    context "with all neutral/normal defaults" do
      before do
        personality.update!(post_frequency: :normal, primary_purpose: :information_seeker)
        # Freeze to Wednesday (wday=3, bonus=0) to isolate variables
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1)) # Wednesday
      end

      it "returns base score of 50 (no bonuses applied)" do
        expect(score).to eq(50)
      end
    end

    context "with post_frequency bonus" do
      before do
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "adds +25 for very_high post_frequency" do
        personality.update!(post_frequency: :very_high)
        expect(score).to eq(50 + 25)
      end

      it "subtracts 25 for very_low post_frequency" do
        personality.update!(post_frequency: :very_low)
        expect(score).to eq(50 - 25)
      end

      it "adds +15 for high post_frequency" do
        personality.update!(post_frequency: :high)
        expect(score).to eq(50 + 15)
      end

      it "subtracts 10 for low post_frequency" do
        personality.update!(post_frequency: :low)
        expect(score).to eq(50 - 10)
      end
    end

    context "with mood bonus" do
      before do
        personality.update!(post_frequency: :normal, primary_purpose: :information_seeker)
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "adds +20 for positive mood" do
        daily_state.update!(mood: :positive)
        expect(score).to eq(50 + 20)
      end

      it "subtracts 10 for negative mood" do
        daily_state.update!(mood: :negative)
        expect(score).to eq(50 - 10)
      end

      it "subtracts 25 for very_negative mood" do
        daily_state.update!(mood: :very_negative)
        expect(score).to eq(50 - 25)
      end
    end

    context "with physical bonus" do
      before do
        personality.update!(post_frequency: :normal, primary_purpose: :information_seeker)
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "adds +10 for good physical" do
        daily_state.update!(physical: :good)
        expect(score).to eq(50 + 10)
      end

      it "subtracts 35 for sick physical" do
        daily_state.update!(physical: :sick)
        expect(score).to eq(50 - 35)
      end
    end

    context "with busyness bonus" do
      before do
        personality.update!(post_frequency: :normal, primary_purpose: :information_seeker)
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "adds +15 for free busyness" do
        daily_state.update!(busyness: :free)
        expect(score).to eq(50 + 15)
      end

      it "subtracts 20 for busy" do
        daily_state.update!(busyness: :busy)
        expect(score).to eq(50 - 20)
      end
    end

    context "with purpose bonus" do
      before do
        personality.update!(post_frequency: :normal)
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "adds +10 for approval_seeker" do
        personality.update!(primary_purpose: :approval_seeker)
        expect(score).to eq(50 + 10)
      end

      it "subtracts 10 for observer" do
        personality.update!(primary_purpose: :observer)
        expect(score).to eq(50 - 10)
      end
    end

    context "with drinking bonus" do
      before do
        personality.update!(post_frequency: :normal, primary_purpose: :information_seeker)
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "adds +5 for drinking_level 1" do
        daily_state.update!(is_drinking: true, drinking_level: 1)
        expect(score).to eq(50 + 5)
      end

      it "adds +10 for drinking_level 2" do
        daily_state.update!(is_drinking: true, drinking_level: 2)
        expect(score).to eq(50 + 10)
      end

      it "adds +15 for drinking_level 3" do
        daily_state.update!(is_drinking: true, drinking_level: 3)
        expect(score).to eq(50 + 15)
      end

      it "adds nothing when not drinking" do
        daily_state.update!(is_drinking: false, drinking_level: 2)
        expect(score).to eq(50)
      end
    end

    context "clamping to 0-100" do
      before do
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 1))
      end

      it "clamps score to 100 when bonuses exceed max" do
        personality.update!(post_frequency: :very_high, primary_purpose: :approval_seeker)
        daily_state.update!(
          mood: :positive, physical: :good, busyness: :free,
          daily_whim: :hyper, is_drinking: true, drinking_level: 3
        )
        # 50 + 25 + 10 + 20 + 10 + 15 + 20 + 15 = 165 -> clamped to 100
        expect(score).to eq(100)
      end

      it "clamps score to 0 when penalties exceed min" do
        personality.update!(post_frequency: :very_low, primary_purpose: :observer)
        daily_state.update!(
          mood: :very_negative, physical: :sick, busyness: :busy,
          daily_whim: :lazy
        )
        # 50 - 25 - 10 - 25 - 35 - 20 - 20 = -85 -> clamped to 0
        expect(score).to eq(0)
      end
    end

    context "weekday bonus" do
      before do
        personality.update!(post_frequency: :normal, primary_purpose: :information_seeker)
      end

      it "applies Monday penalty (-20)" do
        allow(Date).to receive(:current).and_return(Date.new(2026, 3, 30)) # Monday
        expect(score).to eq(50 - 20)
      end

      it "applies Saturday bonus (+15)" do
        allow(Date).to receive(:current).and_return(Date.new(2026, 4, 4)) # Saturday
        expect(score).to eq(50 + 15)
      end
    end
  end
end
