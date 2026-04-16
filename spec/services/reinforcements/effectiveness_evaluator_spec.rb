require "rails_helper"

RSpec.describe Reinforcements::EffectivenessEvaluator do
  describe ".evaluate" do
    it "returns nil average when there are no samples" do
      result = described_class.evaluate("posting_frequency_up")
      expect(result.average_score).to be_nil
      expect(result.sample_size).to eq(0)
      expect(result.low_effectiveness).to be false
    end

    it "flags low_effectiveness only when sample_size >= min_sample" do
      [ 0.1, 0.1 ].each do |s|
        create(:ticket_ledger,
               ticket_type: "improvement",
               improvement_pattern_key: "prompt_tuning",
               effectiveness_score: s)
      end
      result = described_class.evaluate("prompt_tuning")
      expect(result.sample_size).to eq(2)
      expect(result.low_effectiveness).to be false
    end

    it "flags low_effectiveness when average is below threshold and sample_size sufficient" do
      [ 0.1, 0.15, 0.05 ].each do |s|
        create(:ticket_ledger,
               ticket_type: "improvement",
               improvement_pattern_key: "prompt_tuning",
               effectiveness_score: s)
      end
      result = described_class.evaluate("prompt_tuning")
      expect(result.low_effectiveness).to be true
      expect(result.recommend_alternative?).to be true
    end

    it "does not flag when average is above threshold" do
      [ 0.5, 0.6, 0.7 ].each do |s|
        create(:ticket_ledger,
               ticket_type: "improvement",
               improvement_pattern_key: "prompt_tuning",
               effectiveness_score: s)
      end
      result = described_class.evaluate("prompt_tuning")
      expect(result.low_effectiveness).to be false
    end
  end

  describe ".override_reason_code" do
    it "returns the audit reason_code required for strong-willed low-effectiveness filing" do
      expect(described_class.override_reason_code).to eq("low_effectiveness_override")
    end
  end
end
