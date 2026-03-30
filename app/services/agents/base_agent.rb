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
    #
    # コスト設計（output が input の5倍高いため output 削減が最重要）:
    #   - 一次判断: 数値のみ返答（~40 output tokens）
    #   - 理由は execute 判断時のみ追加取得（~150 output tokens）
    #   - モデルは Haiku（Opus の約1/20）
    #
    # 概算コスト（5エージェント・市場時間内のみ・5分ごと）:
    #   一次判断のみ: ~$0.02/日
    #   execute 時の理由取得込み: ~$0.05〜0.10/日（execute は全判断の数%）
    #
    # @param system_prompt [String]
    # @param user_message  [String]
    # @param model [String] デフォルトは Haiku
    # @param max_tokens [Integer]
    # @return [String]
    def call_claude(system_prompt:, user_message:, model: "claude-haiku-4-5-20251001", max_tokens: 80)
      client = Anthropic::Client.new
      response = client.messages(
        parameters: {
          model:      model,
          max_tokens: max_tokens,
          system:     system_prompt,
          messages:   [{ role: "user", content: user_message }]
        }
      )
      response.dig("content", 0, "text").to_s
    rescue => e
      Rails.logger.error "[#{self.class.name}] Claude API error: #{e.message}"
      ""
    end

    # 一次判断用パーサー（数値のみ）
    #
    # AIには以下の最小フォーマットで返答させること（REASONING は含めない）:
    #   JUDGMENT: buy|sell|skip
    #   CONFIDENCE: 0.0〜1.0
    #   VETO: true|false
    #   VETO_REASON: (veto=true の場合のみ、1行で）
    #
    # REASONING は execute 判断時に fetch_reasoning で別途取得する。
    def parse_ai_response(text)
      judgment    = text.match(/JUDGMENT:\s*(buy|sell|skip)/i)&.captures&.first&.downcase || "skip"
      confidence  = text.match(/CONFIDENCE:\s*([0-9.]+)/i)&.captures&.first&.to_f || 0.5
      veto        = text.match(/VETO:\s*(true|false)/i)&.captures&.first == "true"
      veto_reason = text.match(/VETO_REASON:\s*(.+)/i)&.captures&.first&.strip

      AgentResult.new(
        judgment:    judgment,
        confidence:  confidence.clamp(0.0, 1.0),
        reasoning:   nil,  # execute 判断時のみ fetch_reasoning で取得
        veto:        veto,
        veto_reason: veto_reason
      )
    end

    # execute 判断が出た場合のみ呼び出す理由取得メソッド
    # output token を節約するため、通常の skip 判断では呼ばない
    #
    # @param system_prompt [String] 一次判断と同じプロンプト
    # @param user_message  [String] 一次判断と同じメッセージ
    # @param judgment      [String] 一次判断の結果
    # @return [String] 判断理由テキスト
    def fetch_reasoning(system_prompt:, user_message:, judgment:)
      call_claude(
        system_prompt: system_prompt,
        user_message:  "#{user_message}\n\n前回の判断: #{judgment}\nその判断理由を2〜3文で日本語説明してください。",
        max_tokens:    200
      )
    end
  end
end
