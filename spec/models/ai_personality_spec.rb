require "rails_helper"

RSpec.describe AiPersonality, type: :model do
  describe "constants" do
    describe "LEVEL_ENUM" do
      it "defines 5 levels from very_low to very_high" do
        expect(AiPersonality::LEVEL_ENUM.keys).to eq(%i[very_low low normal high very_high])
        expect(AiPersonality::LEVEL_ENUM.values).to eq([1, 2, 3, 4, 5])
      end
    end

    describe "PURPOSE_ENUM" do
      it "defines 8 purpose types" do
        expect(AiPersonality::PURPOSE_ENUM.keys).to contain_exactly(
          :information_seeker, :approval_seeker, :connector, :self_recorder,
          :entertainer, :venter, :observer, :influencer
        )
      end

      it "uses sequential integer values starting from 0" do
        expect(AiPersonality::PURPOSE_ENUM.values).to eq((0..7).to_a)
      end
    end
  end

  describe "enum definitions" do
    subject(:personality) { build_stubbed(:ai_personality) }

    it "defines LEVEL_ENUM-based enums with prefix" do
      %i[
        sociability post_frequency active_time_peak need_for_approval
        emotional_range risk_tolerance self_expression drinking_frequency
        self_esteem empathy jealousy curiosity
      ].each do |attr|
        expect(personality).to respond_to(:"#{attr}_very_low?")
        expect(personality).to respond_to(:"#{attr}_normal?")
        expect(personality).to respond_to(:"#{attr}_very_high?")
      end
    end

    it "defines PURPOSE_ENUM-based enums for primary and secondary purpose" do
      expect(personality).to respond_to(:primary_purpose_information_seeker?)
      expect(personality).to respond_to(:primary_purpose_observer?)
      expect(personality).to respond_to(:secondary_purpose_entertainer?)
    end

    it "defines follow_philosophy enum with prefix" do
      expect(personality).to respond_to(:follow_philosophy_casual?)
      expect(personality).to respond_to(:follow_philosophy_selective?)
      expect(personality).to respond_to(:follow_philosophy_collector?)
    end
  end

  describe "validations" do
    it "is valid with default factory attributes" do
      personality = build(:ai_personality)
      expect(personality).to be_valid
    end

    it "requires presence of all personality attributes" do
      personality = build(:ai_personality, sociability: nil)
      expect(personality).not_to be_valid
      expect(personality.errors[:sociability]).to be_present
    end

    it "requires primary_purpose" do
      personality = build(:ai_personality, primary_purpose: nil)
      expect(personality).not_to be_valid
    end

    it "requires follow_philosophy" do
      personality = build(:ai_personality, follow_philosophy: nil)
      expect(personality).not_to be_valid
    end
  end

  describe "#to_prompt_hash" do
    subject(:prompt_hash) { personality.to_prompt_hash }

    let(:personality) do
      build_stubbed(:ai_personality,
        sociability: :high,
        post_frequency: :very_high,
        active_time_peak: :very_low,
        need_for_approval: :low,
        emotional_range: :normal,
        risk_tolerance: :very_low,
        self_expression: :high,
        self_esteem: :normal,
        empathy: :very_high,
        primary_purpose: :approval_seeker)
    end

    it "returns a hash with Japanese labels" do
      expect(prompt_hash).to be_a(Hash)
      expect(prompt_hash[:sociability]).to eq("高い")
      expect(prompt_hash[:post_frequency]).to eq("非常に高い")
      expect(prompt_hash[:need_for_approval]).to eq("低い")
      expect(prompt_hash[:emotional_range]).to eq("普通")
      expect(prompt_hash[:risk_tolerance]).to eq("非常に低い")
      expect(prompt_hash[:self_expression]).to eq("高い")
      expect(prompt_hash[:self_esteem]).to eq("普通")
      expect(prompt_hash[:empathy]).to eq("非常に高い")
    end

    it "returns active_time_peak as descriptive time label" do
      expect(prompt_hash[:active_time_peak]).to eq("朝型（6〜9時がピーク）")
    end

    it "returns primary_purpose as descriptive label" do
      expect(prompt_hash[:primary_purpose]).to eq("いいねがほしい・バズりたい")
    end

    it "includes expected keys" do
      expected_keys = %i[
        sociability post_frequency active_time_peak need_for_approval
        emotional_range risk_tolerance self_expression self_esteem
        empathy primary_purpose
      ]
      expect(prompt_hash.keys).to match_array(expected_keys)
    end
  end
end
