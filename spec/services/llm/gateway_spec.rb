require "rails_helper"

RSpec.describe Llm::Gateway do
  describe ".enabled?" do
    it "is false by default" do
      expect(described_class.enabled?).to be false
    end

    it "is true when ENV LLM_GATEWAY_ENABLED=1" do
      ENV["LLM_GATEWAY_ENABLED"] = "1"
      expect(described_class.enabled?).to be true
    ensure
      ENV.delete("LLM_GATEWAY_ENABLED")
    end
  end

  describe ".call" do
    it "returns a fallback result when disabled" do
      ENV.delete("LLM_GATEWAY_ENABLED")
      result = described_class.call(purpose: :planner, prompt: "hello", fallback: { x: 1 })
      expect(result.success?).to be false
      expect(result.used_llm).to be false
      expect(result.parsed).to eq({ x: 1 })
      expect(result.fallback_reason).to eq("disabled")
    end

    context "when enabled" do
      before { ENV["LLM_GATEWAY_ENABLED"] = "1" }
      after  { ENV.delete("LLM_GATEWAY_ENABLED") }

      it "returns a success result using LlmClient" do
        allow(LlmClient).to receive(:call).and_return("hello world")

        result = described_class.call(purpose: :planner, prompt: "hi")

        expect(result.success?).to be true
        expect(result.used_llm).to be true
        expect(result.text).to eq("hello world")
      end

      it "parses JSON text when expect_json: true" do
        allow(LlmClient).to receive(:call).and_return('```json\n{"a":1}\n```'.gsub('\n', "\n"))

        result = described_class.call(purpose: :planner, prompt: "hi", expect_json: true)

        expect(result.success?).to be true
        expect(result.parsed).to eq({ "a" => 1 })
      end

      it "returns fallback on LlmClient error" do
        allow(LlmClient).to receive(:call).and_raise(StandardError, "boom")

        result = described_class.call(purpose: :audit, prompt: "hi", fallback: "rule-based")

        expect(result.success?).to be false
        expect(result.used_llm).to be false
        expect(result.parsed).to eq("rule-based")
        expect(result.fallback_reason).to include("error")
      end

      it "treats empty prompt as fallback" do
        result = described_class.call(purpose: :planner, prompt: "   ")

        expect(result.success?).to be false
        expect(result.fallback_reason).to eq("empty_prompt")
      end
    end
  end
end
