module Llm
  # Phase 40 / §32.1: `LlmGateway` は LLM 判断の統一入口。
  #
  # `Planner` / `EffectivenessEvaluator` / `Audits::RecordDecision` などのルールベース判断に
  # LLM 判断を併用する際、ここを通すことで:
  #   - feature flag（`LLM_GATEWAY_ENABLED`）での一括 ON/OFF
  #   - purpose（`:planner` / `:audit` / `:effectiveness` 等）別のモデル/予算制御
  #   - 失敗時の rule-based fallback
  #   - 構造化出力（JSON）のパース
  # を一箇所に集約する。
  #
  # 使い方（augment モード: 既存のルール結果を補強）:
  #   llm_result = Llm::Gateway.call(purpose: :planner, prompt: "...", fallback: { ok: true })
  #   if llm_result.success? && llm_result.parsed.present?
  #     # LLM の提案を使う
  #   else
  #     # ルールベースの既存挙動を使う
  #   end
  #
  # デフォルトは `enabled? = false`。ENV `LLM_GATEWAY_ENABLED=1` で段階的に有効化する。
  class Gateway
    Result = Struct.new(:success, :text, :parsed, :used_llm, :fallback_reason, keyword_init: true) do
      def success?
        success
      end
    end

    PURPOSE_TO_LLM_PURPOSE = {
      planner: :creation,
      audit: :creation,
      effectiveness: :post,
      portfolio: :creation,
      hr: :creation
    }.freeze

    def self.enabled?
      ENV["LLM_GATEWAY_ENABLED"] == "1"
    end

    def self.call(**args)
      new(**args).call
    end

    def initialize(purpose:, prompt:, max_tokens: 1000, expect_json: false, fallback: nil, fallback_reason: nil)
      @purpose = purpose.to_sym
      @prompt = prompt.to_s
      @max_tokens = max_tokens
      @expect_json = expect_json
      @fallback = fallback
      @fallback_reason = fallback_reason
    end

    def call
      return fallback_result("disabled") unless self.class.enabled?
      return fallback_result("empty_prompt") if @prompt.strip.empty?

      text = LlmClient.call(@prompt, purpose: llm_purpose, max_tokens: @max_tokens)
      parsed = parse_json(text) if @expect_json

      Result.new(
        success: true,
        text: text,
        parsed: parsed,
        used_llm: true,
        fallback_reason: nil
      )
    rescue StandardError => e
      Rails.logger.warn("[Llm::Gateway] purpose=#{@purpose} failed: #{e.class}: #{e.message}")
      fallback_result("error:#{e.class}")
    end

    private

    def llm_purpose
      PURPOSE_TO_LLM_PURPOSE.fetch(@purpose, :post)
    end

    def parse_json(text)
      return nil if text.blank?
      cleaned = text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
      JSON.parse(cleaned)
    rescue JSON::ParserError
      nil
    end

    def fallback_result(reason)
      Result.new(
        success: false,
        text: nil,
        parsed: @fallback,
        used_llm: false,
        fallback_reason: @fallback_reason || reason
      )
    end
  end
end
