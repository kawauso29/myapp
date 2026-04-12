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
  end
end
