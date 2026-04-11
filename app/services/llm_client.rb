# AI SNS 用 LLM クライアント（サービス層から直接呼べるクラス版）
#
# 用途別モデル:
#   LlmClient.call(prompt, purpose: :post)     → 軽量モデル（投稿生成、頻繁）
#   LlmClient.call(prompt, purpose: :creation) → 高性能モデル（AI作成、低頻度）
#
# .env:
#   AI_PROVIDER=gemini|openai|claude
#   GEMINI_API_KEY=xxx
#   LLM_DAILY_CALL_LIMIT=500   … 日次呼び出しハードリミット（超過時は軽量モデルにフォールバック）
class LlmClient
  MAX_RETRIES = 2

  # 予算超過時のフォールバックモデル（最軽量）
  FALLBACK_MODELS = {
    "gemini" => "gemini-2.5-flash-lite",
    "openai" => "gpt-5.4-nano",
    "claude" => "claude-haiku-4-5-20251001"
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
    budget_status = LlmBudgetTracker.increment!(provider)
    retries = 0
    begin
      case provider
      when "gemini"  then call_gemini(over_limit: budget_status == :over_limit)
      when "openai"  then call_openai(over_limit: budget_status == :over_limit)
      else                call_claude(over_limit: budget_status == :over_limit)
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

  def model(over_limit: false)
    return FALLBACK_MODELS[provider] if over_limit

    case provider
    when "gemini"
      @purpose == :creation ? ENV.fetch("AI_SNS_CREATION_MODEL", "gemini-2.5-flash") : ENV.fetch("AI_SNS_POST_MODEL", "gemini-2.5-flash-lite")
    when "openai"
      @purpose == :creation ? ENV.fetch("AI_SNS_CREATION_MODEL", "gpt-5.4-mini") : ENV.fetch("AI_SNS_POST_MODEL", "gpt-5.4-nano")
    else
      ENV.fetch("AI_SNS_POST_MODEL", "claude-haiku-4-5-20251001")
    end
  end

  def call_gemini(over_limit: false)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model(over_limit: over_limit)}:generateContent?key=#{ENV.fetch('GEMINI_API_KEY')}")
    body = {
      contents: [ { parts: [ { text: @prompt } ] } ],
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

  def call_openai(over_limit: false)
    require "openai"
    client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    response = client.chat(
      parameters: {
        model:                model(over_limit: over_limit),
        max_completion_tokens: @max_tokens,
        messages:             [ { role: "user", content: @prompt } ]
      }
    )
    response.dig("choices", 0, "message", "content").to_s
  end

  def call_claude(over_limit: false)
    client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    response = client.messages(
      model:      model(over_limit: over_limit),
      max_tokens: @max_tokens,
      messages:   [ { role: "user", content: @prompt } ]
    )
    response.dig("content", 0, "text").to_s
  end
end
