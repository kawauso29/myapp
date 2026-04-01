require "rails_helper"

RSpec.describe AiAction::LlmResponse::PostValidator do
  subject(:validator) { described_class.new }

  describe "#validate" do
    context "with valid JSON" do
      let(:raw_text) do
        {
          content: "Hello world!",
          tags: ["greeting", "test"],
          mood_expressed: "positive",
          emoji_used: true
        }.to_json
      end

      it "returns ok: true with parsed data" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be true
        expect(result[:data][:content]).to eq("Hello world!")
        expect(result[:data][:tags]).to eq(["greeting", "test"])
        expect(result[:data][:mood_expressed]).to eq("positive")
        expect(result[:data][:emoji_used]).to be true
      end
    end

    context "with empty content" do
      let(:raw_text) { { content: "", mood_expressed: "neutral" }.to_json }

      it "returns error" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be false
        expect(result[:error]).to eq("contentが空")
      end
    end

    context "with nil content" do
      let(:raw_text) { { mood_expressed: "neutral" }.to_json }

      it "returns error" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be false
        expect(result[:error]).to eq("contentが空")
      end
    end

    context "with content exceeding 140 characters" do
      let(:raw_text) do
        { content: "a" * 141, mood_expressed: "neutral" }.to_json
      end

      it "returns error" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be false
        expect(result[:error]).to eq("contentが140文字超")
      end
    end

    context "with content at exactly 140 characters" do
      let(:raw_text) do
        { content: "a" * 140, mood_expressed: "neutral" }.to_json
      end

      it "returns ok" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be true
        expect(result[:data][:content]).to eq("a" * 140)
      end
    end

    context "with invalid mood_expressed" do
      let(:raw_text) do
        { content: "Hello", mood_expressed: "excited" }.to_json
      end

      it "returns error" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be false
        expect(result[:error]).to eq("mood_expressedが不正")
      end
    end

    context "with missing mood_expressed" do
      let(:raw_text) { { content: "Hello" }.to_json }

      it "returns error" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be false
        expect(result[:error]).to eq("mood_expressedが不正")
      end
    end

    context "with markdown code fences wrapping JSON" do
      let(:raw_text) do
        <<~TEXT
          ```json
          {"content": "Stripped!", "mood_expressed": "neutral", "tags": []}
          ```
        TEXT
      end

      it "strips fences and parses successfully" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be true
        expect(result[:data][:content]).to eq("Stripped!")
      end
    end

    context "with invalid JSON" do
      it "returns parse error" do
        result = validator.validate("not json at all")

        expect(result[:ok]).to be false
        expect(result[:error]).to eq("JSONパースに失敗")
      end
    end

    context "with emoji_used as non-boolean" do
      let(:raw_text) do
        { content: "Hi", mood_expressed: "neutral", emoji_used: "yes" }.to_json
      end

      it "treats non-true values as false" do
        result = validator.validate(raw_text)

        expect(result[:ok]).to be true
        expect(result[:data][:emoji_used]).to be false
      end
    end

    context "tags handling" do
      it "limits tags to 5" do
        raw = { content: "Hi", mood_expressed: "neutral",
                tags: ["a", "b", "c", "d", "e", "f"] }.to_json
        result = validator.validate(raw)

        expect(result[:data][:tags].length).to eq(5)
      end

      it "filters blank tags" do
        raw = { content: "Hi", mood_expressed: "neutral",
                tags: ["a", "", nil, "b"] }.to_json
        result = validator.validate(raw)

        expect(result[:data][:tags]).to eq(["a", "b"])
      end
    end
  end
end
