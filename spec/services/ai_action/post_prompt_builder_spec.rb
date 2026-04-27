require "rails_helper"

RSpec.describe AiAction::PostPromptBuilder do
  let(:ai_user) { create(:ai_user) }
  let(:daily_state) do
    create(:ai_daily_state, ai_user: ai_user, today_events: [], stress_level: 30,
                             social_battery: 60, concentration: :normal_concentration,
                             appetite: :normal_appetite, morning_mood: :ok_morning,
                             going_out: false, hourly_states: [])
  end
  let(:motivation) { { primary: :sharing } }

  subject(:builder) { described_class.new(ai_user, daily_state, motivation) }

  describe "#event_guidance_section" do
    context "when there are no events" do
      it "returns empty string" do
        expect(builder.send(:event_guidance_section)).to eq("")
      end
    end

    context "on cherry_blossom season with outgoing AI" do
      before do
        daily_state.today_events = [ "cherry_blossom" ]
        ai_user.ai_personality.update!(sociability: :high)
      end

      it "includes cherry blossom guidance encouraging outgoing posts" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("お花見シーズン")
        expect(section).to include("外出")
      end
    end

    context "on cherry_blossom season with introverted AI" do
      before do
        daily_state.today_events = [ "cherry_blossom" ]
        ai_user.ai_personality.update!(sociability: :low)
      end

      it "includes cherry blossom guidance with a calmer tone" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("お花見シーズン")
        expect(section).not_to include("外出して")
      end
    end

    context "on valentine with coupled AI" do
      before do
        daily_state.today_events = [ "valentine" ]
        ai_user.ai_profile.update!(relationship_status: :in_relationship)
      end

      it "includes romantic valentine guidance" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("バレンタインデー")
        expect(section).to include("パートナー")
      end
    end

    context "on valentine with single AI" do
      before do
        daily_state.today_events = [ "valentine" ]
        ai_user.ai_profile.update!(relationship_status: :single)
      end

      it "includes solo valentine guidance" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("バレンタインデー")
        expect(section).not_to include("パートナー")
      end
    end

    context "on christmas_eve with married AI" do
      before do
        daily_state.today_events = [ "christmas_eve" ]
        ai_user.ai_profile.update!(relationship_status: :married)
      end

      it "includes romantic christmas guidance" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("クリスマスイブ")
        expect(section).to include("ロマンチック")
      end
    end

    context "on new_year_eve" do
      before { daily_state.today_events = [ "new_year_eve" ] }

      it "includes year-end reflection guidance" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("大晦日")
        expect(section).to include("振り返り")
      end
    end

    context "with multiple events" do
      before { daily_state.today_events = [ "cherry_blossom", "payday" ] }

      it "includes guidance for all events" do
        section = builder.send(:event_guidance_section)
        expect(section).to include("お花見シーズン")
        expect(section).to include("給料日")
      end
    end
  end

  describe "#build (event guidance in prompt)" do
    context "when there are events" do
      before { daily_state.today_events = [ "halloween" ] }

      it "includes the event guidance section in the built prompt" do
        prompt = builder.build
        expect(prompt).to include("今日のイベント投稿テーマ")
        expect(prompt).to include("ハロウィン")
      end
    end

    context "when there are no events" do
      it "does not include the event guidance header in the built prompt" do
        prompt = builder.build
        expect(prompt).not_to include("今日のイベント投稿テーマ")
      end
    end
  end

  describe "EVENT_LABELS" do
    it "maps event keys to Japanese labels" do
      expect(described_class::EVENT_LABELS["cherry_blossom"]).to eq("お花見シーズン")
      expect(described_class::EVENT_LABELS["christmas_eve"]).to eq("クリスマスイブ")
      expect(described_class::EVENT_LABELS["valentine"]).to eq("バレンタインデー")
      expect(described_class::EVENT_LABELS["new_year_eve"]).to eq("大晦日")
    end
  end

  describe "#external_context_section (Japanese event names)" do
    before { daily_state.today_events = [ "cherry_blossom" ] }

    it "shows Japanese event name instead of the raw key" do
      section = builder.send(:external_context_section)
      expect(section).to include("お花見シーズン")
      expect(section).not_to include("cherry_blossom")
    end
  end
end
