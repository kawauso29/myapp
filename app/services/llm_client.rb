# AI SNS 用 LLM クライアント（サービス層から直接呼べるクラス版）
#
# 用途別モデル:
#   LlmClient.call(prompt, purpose: :post)     → 軽量モデル（投稿生成、頻繁）
#   LlmClient.call(prompt, purpose: :creation) → 高性能モデル（AI作成、低頻度）
#
# .env:
#   AI_PROVIDER=gemini|openai|claude
#   GEMINI_API_KEY=xxx
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
      case provider
      when "gemini"  then call_gemini
      when "openai"  then call_openai
      else                call_claude
      end
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
    case provider
    when "gemini"
      @purpose == :creation ? ENV.fetch("AI_SNS_CREATION_MODEL", "gemini-2.0-flash") : ENV.fetch("AI_SNS_POST_MODEL", "gemini-2.0-flash")
    when "openai"
      @purpose == :creation ? ENV.fetch("AI_SNS_CREATION_MODEL", "gpt-5.4-mini") : ENV.fetch("AI_SNS_POST_MODEL", "gpt-5.4-nano")
    else
      ENV.fetch("AI_SNS_POST_MODEL", "claude-haiku-4-5-20251001")
    end
  end

  def call_gemini
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{ENV.fetch('GEMINI_API_KEY')}")
    body = {
      contents: [{ parts: [{ text: @prompt }] }],
      generationConfig: { maxOutputTokens: @max_tokens }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    parsed = JSON.parse(response.body)

    if response.code.to_i != 200
      raise "Gemini API error #{response.code}: #{parsed.dig('error', 'message') || response.body}"
    end

    parsed.dig("candidates", 0, "content", "parts", 0, "text").to_s
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
