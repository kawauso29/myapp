# マクロ環境エージェント
#
# 担当: 米国マクロ経済環境（金利・ドル・景気）の判断
# 主な判断要素:
#   - DXY（ドル指数）のトレンド
#   - 米国債10年利回り
#   - Fed の政策スタンス
#   - リスクオン/リスクオフのセンチメント

module Agents
  class MacroAgent < BaseAgent
    private

    def agent_type
      "macro"
    end

    def analyze(snapshot)
      raw = snapshot.raw_data&.symbolize_keys || {}

      system_prompt = <<~PROMPT
        あなたはNAS100（ナスダック100）専門のマクロ経済アナリストです。
        与えられたマクロ経済データを分析し、NAS100の売買判断を行ってください。

        判断ルール:
        - DXY上昇（ドル高）はNAS100に逆風
        - 金利上昇（特に急上昇）はNAS100に逆風
        - VIXが20を超えている場合はリスクオフとして慎重に判断
        - 景気後退懸念が強い局面はskipを推奨

        必ず以下のフォーマットで回答してください:
        JUDGMENT: buy|sell|skip
        CONFIDENCE: 0.0〜1.0の数値
        VETO: true|false（市場環境が極めて悪い場合はtrue）
        VETO_REASON: （vetoがtrueの場合のみ記載）
        REASONING: 判断の根拠を日本語で記載
      PROMPT

      user_message = <<~MSG
        現在のマクロ経済データ:
        - NAS100価格: #{snapshot.nas100_price}
        - VIX: #{snapshot.vix}
        - DXY（ドル指数）: #{snapshot.dxy}
        - 米国債10年利回り: #{raw[:us10y_yield] || "データなし"}
        - 市場状態: #{snapshot.state}（確信度: #{(snapshot.state_confidence.to_f * 100).round}%）
        - リスクオン/オフ指標: #{raw[:risk_sentiment] || "データなし"}

        NAS100の売買判断を行ってください。
      MSG

      response = call_claude(system_prompt: system_prompt, user_message: user_message)
      return fallback_result("Claude APIレスポンスなし") if response.blank?

      parse_ai_response(response)
    end

    def fallback_result(reason)
      AgentResult.new(
        judgment:    "skip",
        confidence:  0.5,
        reasoning:   "フォールバック: #{reason}",
        veto:        false,
        veto_reason: nil
      )
    end
  end
end
