require "rails_helper"

RSpec.describe Linestamp::PromptComposer do
  let(:brand) do
    Linestamp::Brand.create!(
      slug: "nemuinu",
      character_name: "ねむ犬",
      series_name: "在宅ワークのゆる犬",
      description: "眠そうな犬",
      two_part_definition: "ねむ犬は「かわいい犬」ではない",
      tone_axes: { gentle: 0.95, cute: 0.7 },
      character_parts: { eyes: "半目", mouth: "小さな口", ears: "垂れ耳", body: "白い2頭身", limbs: "短い手足", tail: "しっぽ", collar: "水色首輪" },
      font_spec: { primary: "太丸ゴシック", color: "#5C3A2E", outline: "太い白フチ" },
      background_color_for_gen: "#3CB371"
    )
  end
  let(:pack) do
    brand.packs.create!(
      series_theme: "在宅ワーク基本",
      position: 1,
      layer: "core_work",
      world_view: "朝から夕方の在宅勤務",
      usage_scenes: ["朝の起動", "PC作業中"],
      target_emotions: ["気まずさ", "ねぎらい"]
    )
  end
  let(:stamp) do
    pack.stamps.create!(
      position: 1,
      label: "いま仕事中だよ",
      situation: "PC前で作業",
      intent: "返信遅延の申し訳なさ通知",
      usage_scene: "返信できない時",
      pose_spec: "ノートPC覗き込み",
      props: "ノートPC",
      search_keywords: ["仕事中", "PC"],
      communication_purpose: "話せないが無視じゃない"
    )
  end
  let(:composer) { described_class.new }

  describe "#compose_brand_prompt" do
    it "returns a prompt containing character parts" do
      prompt = composer.compose_brand_prompt(brand)
      expect(prompt).to include("半目")
      expect(prompt).to include("太丸ゴシック")
      expect(prompt).to include("#3CB371")
    end

    it "includes the two-part definition" do
      prompt = composer.compose_brand_prompt(brand)
      expect(prompt).to include("ねむ犬は「かわいい犬」ではない")
    end
  end

  describe "#compose_pack_sheet_prompt" do
    it "returns a prompt containing pack theme and brand info" do
      prompt = composer.compose_pack_sheet_prompt(pack)
      expect(prompt).to include("在宅ワーク基本")
      expect(prompt).to include("core_work")
      expect(prompt).to include("#3CB371")
    end
  end

  describe "#compose_stamp_prompt" do
    it "returns a prompt containing stamp details" do
      prompt = composer.compose_stamp_prompt(stamp)
      expect(prompt).to include("いま仕事中だよ")
      expect(prompt).to include("返信遅延の申し訳なさ通知")
      expect(prompt).to include("ノートPC覗き込み")
      expect(prompt).to include("370")
    end
  end
end
