require "rails_helper"

RSpec.describe Linestamp::Brand, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:character_name) }
    it { is_expected.to validate_presence_of(:series_name) }

    it "validates uniqueness of slug" do
      described_class.create!(slug: "test", character_name: "Test", series_name: "Test Series")
      brand = described_class.new(slug: "test", character_name: "Test2", series_name: "Test2 Series")
      expect(brand).not_to be_valid
    end

    it "fills background_color_for_gen with chroma green when blank" do
      brand = described_class.create!(slug: "green-default", character_name: "Test", series_name: "Test Series")
      expect(brand.background_color_for_gen).to eq("#3CB371")
    end

    it "rejects non-chroma-green background_color_for_gen" do
      brand = described_class.new(
        slug: "soft-green",
        character_name: "Test",
        series_name: "Test Series",
        background_color_for_gen: "#E8F5EC"
      )
      expect(brand).not_to be_valid
      expect(brand.errors[:background_color_for_gen]).to include("は #3CB371(透過用シーグリーン)固定です")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:packs) }
  end

  describe "AASM states" do
    let(:brand) { described_class.create!(slug: "test-brand", character_name: "Test Brand", series_name: "Test Series") }

    it "starts as planned" do
      expect(brand).to be_planned
    end

    it "transitions planned -> prompt_ready when prompt is set" do
      brand.update!(brand_prompt: "test prompt")
      brand.mark_prompt_ready!
      expect(brand).to be_prompt_ready
    end

    it "cannot transition to prompt_ready without prompt" do
      expect(brand.may_mark_prompt_ready?).to be false
    end
  end

  describe "structured fields" do
    let(:brand) do
      described_class.create!(
        slug: "nemuinu",
        character_name: "ねむ犬",
        series_name: "在宅ワークのゆる犬",
        two_part_definition: "ねむ犬は「かわいい犬」ではない",
        tone_axes: { gentle: 0.95, cute: 0.7 },
        character_parts: { eyes: "半目", mouth: "小さな口" },
        font_spec: { primary: "太丸ゴシック", color: "#5C3A2E" },
        background_color_for_gen: "#3CB371"
      )
    end

    it "stores tone_axes as hash" do
      expect(brand.tone_axes["gentle"]).to eq(0.95)
    end

    it "stores character_parts as hash" do
      expect(brand.character_parts["eyes"]).to eq("半目")
    end

    it "stores font_spec as hash" do
      expect(brand.font_spec["primary"]).to eq("太丸ゴシック")
    end

    it "has display_name returning character_name" do
      expect(brand.display_name).to eq("ねむ犬")
    end
  end
end
