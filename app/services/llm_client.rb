# AI SNS 用 LLM クライアント（サービス層から直接呼べるクラス版）
#
# 用途別モデル:
#   LlmClient.call(prompt, purpose: :post)     → nano（投稿生成、頻繁）
#   LlmClient.call(prompt, purpose: :creation) → mini（AI作成、低頻度）
#
# .env:
#   AI_PROVIDER=openai
#   AI_SNS_POST_MODEL=gpt-5.4-nano
#   AI_SNS_CREATION_MODEL=gpt-5.4-mini
class LlmClient
  MAX_RETRIES = 2

  def self.call(prompt, purpose: :post, max_tokens: 1000)
    new(prompt, purpose: purpose, max_tokens: max_tokens).call
  end

  def initialize(prompt, purpose:, max_tokens:)
    @prompt = prompt
    @purpose = purpose
    @max_tokens = max_tokens
  end

  def call
    retries = 0
    begin
      provider == "openai" ? call_openai : call_claude
    rescue => e
      if retries < MAX_RETRIES
        retries += 1
        sleep(2**retries)
        retry
      end
      Rails.logger.error("[LlmClient] #{e.class}: #{e.message}")
      raise
    end
  end

  private

  def provider
    ENV.fetch("AI_PROVIDER", "openai")
  end

  def model
    case @purpose
    when :creation
      ENV.fetch("AI_SNS_CREATION_MODEL", provider == "openai" ? "gpt-5.4-mini" : "claude-haiku-4-5-20251001")
    else
      ENV.fetch("AI_SNS_POST_MODEL", provider == "openai" ? "gpt-5.4-nano" : "claude-haiku-4-5-20251001")
    end
  end

  def call_openai
    require "openai"
    client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    response = client.chat(
      parameters: {
        model:      model,
        max_tokens: @max_tokens,
        messages:   [{ role: "user", content: @prompt }]
      }
    )
    response.dig("choices", 0, "message", "content").to_s
  end

  def call_claude
    client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    response = client.messages(
      model:      model,
      max_tokens: @max_tokens,
      messages:   [{ role: "user", content: @prompt }]
    )
    response.dig("content", 0, "text").to_s
  end
end
