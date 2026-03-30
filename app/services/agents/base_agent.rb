# Layer 1: エージェント基底クラス
#
# 全エージェントが継承する共通インターフェース。
# サブクラスは #analyze を実装すること。
#
# 戻り値の規約 (AgentResult):
#   judgment:   "buy" / "sell" / "skip"
#   confidence: 0.0〜1.0
#   reasoning:  AIの判断根拠テキスト
#   veto:       true/false（強い反対意見）
#   veto_reason: 拒否権の理由

module Agents
  class BaseAgent
    AgentResult = Struct.new(:judgment, :confidence, :reasoning, :veto, :veto_reason, keyword_init: true)

    # @param snapshot [MarketSnapshot]
    # @return [AgentResult]
    def call(snapshot)
      result = analyze(snapshot)
      persist_judgment(snapshot, result)
      result
    end

    private

    # サブクラスで実装
    # @return [AgentResult]
    def analyze(_snapshot)
      raise NotImplementedError, "#{self.class.name}#analyze を実装してください"
    end

    def agent_type
      raise NotImplementedError, "#{self.class.name}#agent_type を実装してください"
    end

    def persist_judgment(snapshot, result)
      AgentJudgment.create!(
        market_snapshot: snapshot,
        agent_type:      agent_type,
        judgment:        result.judgment,
        confidence:      result.confidence,
        reasoning:       result.reasoning,
        veto:            result.veto,
        veto_reason:     result.veto_reason
      )
    end

    # Claude API を呼び出す共通ヘルパー
    # @param system_prompt [String]
    # @param user_message  [String]
    # @return [String] AIの応答テキスト
    def call_claude(system_prompt:, user_message:)
      client = Anthropic::Client.new
      response = client.messages(
        parameters: {
          model:      "claude-opus-4-6",
          max_tokens: 1024,
          system:     system_prompt,
          messages:   [{ role: "user", content: user_message }]
        }
      )
      response.dig("content", 0, "text").to_s
    rescue => e
      Rails.logger.error "[#{self.class.name}] Claude API error: #{e.message}"
      ""
    end

    # AIレスポンスから判断・確信度・理由を抽出する共通パーサー
    # AIには必ず以下のフォーマットで返答させること:
    #   JUDGMENT: buy|sell|skip
    #   CONFIDENCE: 0.0〜1.0
    #   VETO: true|false
    #   VETO_REASON: (vetoがtrueの場合のみ)
    #   REASONING: ...
    def parse_ai_response(text)
      judgment    = text.match(/JUDGMENT:\s*(buy|sell|skip)/i)&.captures&.first&.downcase || "skip"
      confidence  = text.match(/CONFIDENCE:\s*([0-9.]+)/i)&.captures&.first&.to_f || 0.5
      veto        = text.match(/VETO:\s*(true|false)/i)&.captures&.first == "true"
      veto_reason = text.match(/VETO_REASON:\s*(.+)/i)&.captures&.first&.strip
      reasoning   = text.match(/REASONING:\s*(.+)/im)&.captures&.first&.strip || text

      AgentResult.new(
        judgment:    judgment,
        confidence:  confidence.clamp(0.0, 1.0),
        reasoning:   reasoning,
        veto:        veto,
        veto_reason: veto_reason
      )
    end
  end
end
