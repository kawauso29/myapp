require "rails_helper"

RSpec.describe Linestamp::Pack, type: :model do
  let(:brand) { Linestamp::Brand.create!(slug: "test-brand", character_name: "Test Brand", series_name: "Test Series") }

  describe "validations" do
    it { is_expected.to validate_presence_of(:series_theme) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:brand) }
    it { is_expected.to have_many(:stamps) }
    it { is_expected.to have_many(:submissions) }
    it { is_expected.to belong_to(:image_spec).optional }
    it { is_expected.to belong_to(:main_source_stamp).optional }
    it { is_expected.to belong_to(:tab_source_stamp).optional }
  end

  describe "AASM states" do
    let(:pack) { brand.packs.create!(series_theme: "Pack 1", position: 1) }

    it "starts as planned" do
      expect(pack).to be_planned
    end

    it "transitions planned -> prompt_ready when sheet_prompt set" do
      pack.update!(sheet_prompt: "test prompt")
      pack.mark_prompt_ready!
      expect(pack).to be_prompt_ready
    end

    it "cannot transition to prompt_ready without sheet_prompt" do
      expect(pack.may_mark_prompt_ready?).to be false
    end
  end

  describe "structured fields" do
    let(:pack) do
      brand.packs.create!(
        series_theme: "在宅ワーク基本",
        position: 1,
        slug: "pack_001",
        layer: "core_work",
        world_view: "朝から夕方の在宅勤務",
        usage_scenes: %w[朝の起動 PC作業中],
        target_emotions: %w[気まずさ ねぎらい],
        excluded_elements: "雲・星"
      )
    end

    it "stores usage_scenes as array" do
      expect(pack.usage_scenes).to eq(%w[朝の起動 PC作業中])
    end

    it "validates layer inclusion" do
      pack.layer = "invalid"
      expect(pack).not_to be_valid
    end

    it "has display_name returning series_theme" do
      expect(pack.display_name).to eq("在宅ワーク基本")
    end
  end
end
