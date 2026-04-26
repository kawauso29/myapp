require "rails_helper"

RSpec.describe Daily::DailyStateGenerator do
  let(:ai_user) { create(:ai_user) }
  let(:generator) { described_class.new(ai_user) }

  describe "seasonal/event modifiers" do
    context "on valentine" do
      it "gives higher mood bonus for coupled AI than single AI" do
        ai_user.ai_profile.update!(relationship_status: :single)
        single_bonus = generator.send(:event_mood_bonus, [ "valentine" ])

        ai_user.ai_profile.update!(relationship_status: :in_relationship)
        coupled_bonus = generator.send(:event_mood_bonus, [ "valentine" ])

        expect(coupled_bonus).to be > single_bonus
      end
    end

    it "boosts post motivation for year-end reflection events" do
      motivation = generator.send(:generate_post_motivation, :neutral, [ "new_year_eve" ])
      expect(motivation).to eq(90)
    end

    it "makes timeline urge high on new year events" do
      urge = generator.send(:generate_timeline_urge, :very_negative, [ "new_year" ])
      expect(urge).to eq(:high_urge)
    end

    it "treats cherry blossom as an outing day for sociable AI" do
      ai_user.ai_personality.update!(sociability: :high)

      expect(generator.send(:cherry_blossom_outing_day?, [ "cherry_blossom" ])).to be(true)
    end

    it "applies emotion ripple deltas to generated stress and post_motivation" do
      generator = described_class.new(ai_user)
      allow(generator).to receive(:carry_fatigue).and_return(0)
      allow(generator).to receive(:generate_physical).and_return(:normal_physical)
      allow(generator).to receive(:load_today_events).and_return([])
      allow(generator).to receive(:generate_mood).and_return(:neutral)
      allow(generator).to receive(:generate_energy).and_return(:normal_energy)
      allow(generator).to receive(:generate_busyness).and_return(:normal_busyness)
      allow(generator).to receive(:generate_drinking).and_return(false)
      allow(generator).to receive(:pick_daily_whim).and_return(:normal_whim)
      allow(generator).to receive(:generate_timeline_urge).and_return(:normal_urge)
      allow(generator).to receive(:generate_stress_level).and_return(30)
      allow(generator).to receive(:generate_social_battery).and_return(70)
      allow(generator).to receive(:generate_concentration).and_return(:normal_concentration)
      allow(generator).to receive(:generate_appetite).and_return(:normal_appetite)
      allow(generator).to receive(:generate_morning_mood).and_return(:ok_morning)
      allow(generator).to receive(:generate_going_out).and_return(false)
      allow(generator).to receive(:generate_post_motivation).and_return(40)
      allow(Daily::EmotionRippleEffect).to receive(:deltas).with(ai_user, date: Date.current).and_return({
        stress_delta: 12,
        post_motivation_delta: 15
      })

      state = generator.generate

      expect(state.stress_level).to eq(42)
      expect(state.post_motivation).to eq(55)
    end

    it "integrates with real emotion ripple effects based on relationship state" do
      close_friend = create(:ai_user)
      create(:ai_relationship, ai_user: ai_user, target_ai_user: close_friend, relationship_type: :close_friend, interaction_score: 100)
      create(:ai_daily_state, ai_user: close_friend, date: Date.current, mood: :very_negative)

      generator = described_class.new(ai_user)
      allow(generator).to receive(:carry_fatigue).and_return(0)
      allow(generator).to receive(:generate_physical).and_return(:normal_physical)
      allow(generator).to receive(:load_today_events).and_return([])
      allow(generator).to receive(:generate_mood).and_return(:neutral)
      allow(generator).to receive(:generate_energy).and_return(:normal_energy)
      allow(generator).to receive(:generate_busyness).and_return(:normal_busyness)
      allow(generator).to receive(:generate_drinking).and_return(false)
      allow(generator).to receive(:pick_daily_whim).and_return(:normal_whim)
      allow(generator).to receive(:generate_timeline_urge).and_return(:normal_urge)
      allow(generator).to receive(:generate_stress_level).and_return(30)
      allow(generator).to receive(:generate_social_battery).and_return(70)
      allow(generator).to receive(:generate_concentration).and_return(:normal_concentration)
      allow(generator).to receive(:generate_appetite).and_return(:normal_appetite)
      allow(generator).to receive(:generate_morning_mood).and_return(:ok_morning)
      allow(generator).to receive(:generate_going_out).and_return(false)
      allow(generator).to receive(:generate_post_motivation).and_return(40)

      state = generator.generate

      expect(state.stress_level).to be > 30
      expect(state.post_motivation).to be > 40
    end
  end
end
