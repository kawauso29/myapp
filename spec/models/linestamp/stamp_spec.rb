require "rails_helper"

RSpec.describe Linestamp::Stamp, type: :model do
  let(:brand) { Linestamp::Brand.create!(slug: "test-brand", character_name: "Test Brand", series_name: "Test Series") }
  let(:pack) { brand.packs.create!(series_theme: "Pack 1", position: 1) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:pack) }
  end

  describe "AASM states" do
    let(:stamp) { pack.stamps.create!(position: 1) }

    it "starts as planned" do
      expect(stamp).to be_planned
    end

    it "transitions planned -> prompt_ready when prompt set" do
      stamp.update!(prompt: "test prompt")
      stamp.mark_prompt_ready!
      expect(stamp).to be_prompt_ready
    end

    it "cannot transition to prompt_ready without prompt" do
      expect(stamp.may_mark_prompt_ready?).to be false
    end
  end

  describe "structured fields" do
    let(:stamp) do
      pack.stamps.create!(
        position: 1,
        label: "いま仕事中だよ",
        situation: "PC前で作業",
        intent: "返信遅延の申し訳なさ通知",
        usage_scene: "返信できない時",
        pose_spec: "ノートPC覗き込み",
        props: "ノートPC",
        search_keywords: %w[仕事中 PC 返事],
        communication_purpose: "話せないが無視じゃないと伝える"
      )
    end

    it "stores search_keywords as array" do
      expect(stamp.search_keywords).to eq(%w[仕事中 PC 返事])
    end

    it "has display_label returning label" do
      expect(stamp.display_label).to eq("いま仕事中だよ")
    end

    it "has display_label fallback to position" do
      stamp2 = pack.stamps.create!(position: 2)
      expect(stamp2.display_label).to eq("#2")
    end
  end
end
