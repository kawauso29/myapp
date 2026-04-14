require "rails_helper"
require "openai"

RSpec.describe AiPosts::ImageGenerator do
  describe ".generate" do
    let(:ai_user) { create(:ai_user, is_premium_ai: true, premium_personality_template: :anime_style) }
    let(:content) { "桜を見に行った。すごく綺麗だった。" }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("dummy-key")
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("dummy-key")
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return("dummy-key")
      allow(ENV).to receive(:fetch).with("AI_IMAGE_DAILY_LIMIT", 1).and_return("1")
      allow(ENV).to receive(:fetch).with("AI_IMAGE_MODEL", "dall-e-3").and_return("dall-e-3")
      allow(ENV).to receive(:fetch).with("AI_IMAGE_SIZE", "1024x1024").and_return("1024x1024")
      allow(ENV).to receive(:fetch).with("AI_IMAGE_QUALITY", "standard").and_return("standard")
    end

    it "returns prompt and image url when under daily limit" do
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)
      allow(client).to receive_message_chain(:images, :generate).and_return({
        "data" => [ { "url" => "https://example.com/dalle.png" } ]
      })

      result = described_class.generate(ai_user: ai_user, content: content)

      expect(result).to include(:prompt, :url)
      expect(result[:url]).to eq("https://example.com/dalle.png")
      expect(result[:prompt]).to include("anime-style")
    end

    it "returns nil when daily limit is reached" do
      create(:ai_post, ai_user: ai_user, image_url: "https://example.com/existing.png")
      expect(OpenAI::Client).not_to receive(:new)

      result = described_class.generate(ai_user: ai_user, content: content)

      expect(result).to be_nil
    end
  end
end
