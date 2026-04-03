# AI SNS 用 LLM クライアント（サービス層から直接呼べるクラス版）
#
# 用途別モデル:
#   LlmClient.call(prompt, purpose: :post)     → 投稿生成（頻繁）
#   LlmClient.call(prompt, purpose: :creation) → AI作成（低頻度）
#
# .env でプロバイダーとモデルを切り替え可能:
#
#   # Gemini（無料枠あり・推奨）
#   AI_PROVIDER=gemini
#   GEMINI_API_KEY=your_key
#   AI_SNS_POST_MODEL=gemini-2.0-flash
#   AI_SNS_CREATION_MODEL=gemini-2.0-flash
#
#   # OpenAI
#   AI_PROVIDER=openai
#   OPENAI_API_KEY=your_key
#   AI_SNS_POST_MODEL=gpt-4o-mini
#   AI_SNS_CREATION_MODEL=gpt-4o-mini
#
#   # Claude (Anthropic)
#   AI_PROVIDER=claude
#   ANTHROPIC_API_KEY=your_key
#   AI_SNS_POST_MODEL=claude-haiku-4-5-20251001
#   AI_SNS_CREATION_MODEL=claude-haiku-4-5-20251001
class LlmClient
  MAX_RETRIES = 2

  PROVIDER_DEFAULTS = {
    "gemini" => {
      post:     "gemini-2.0-flash",
      creation: "gemini-2.0-flash",
      uri_base: "https://generativelanguage.googleapis.com/v1beta/openai/",
      api_key_env: "GEMINI_API_KEY"
    },
    "openai" => {
      post:     "gpt-4o-mini",
      creation: "gpt-4o-mini",
      uri_base: "https://api.openai.com/",
      api_key_env: "OPENAI_API_KEY"
    }
  }.freeze

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
      provider == "claude" ? call_claude : call_openai_compatible
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
    ENV.fetch("AI_PROVIDER", "gemini")
  end

  def model
    default = PROVIDER_DEFAULTS.dig(provider, @purpose == :creation ? :creation : :post) ||
              "gemini-2.0-flash"
    ENV.fetch(@purpose == :creation ? "AI_SNS_CREATION_MODEL" : "AI_SNS_POST_MODEL", default)
  end

  def call_openai_compatible
    config = PROVIDER_DEFAULTS.fetch(provider, PROVIDER_DEFAULTS["gemini"])
    api_key = ENV.fetch(config[:api_key_env])

    require "openai"
    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: config[:uri_base]
    )
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
