# モメンタム・フローエージェント
#
# 担当: 価格モメンタムと資金フローの判断
# 主な判断要素:
#   - 短期モメンタム（1h/4h/1d）
#   - 出来高トレンド（上昇時の出来高増加は強い）
#   - 機関投資家のフロー
#   - オプション市場のポジショニング（Put/Call Ratio）

module Agents
  class MomentumAgent < BaseAgent
    private

    def agent_type
      "momentum"
    end

    def analyze(snapshot)
      raw = snapshot.raw_data&.symbolize_keys || {}

      system_prompt = <<~PROMPT
        あなたはNAS100（ナスダック100）専門のモメンタム・フロー分析エージェントです。
        価格モメンタムと市場の資金フローを分析し、売買判断を行ってください。

        判断ルール:
        - 複数の時間軸でモメンタムが一致している場合は確信度が高い
        - 上昇局面での出来高増加は強いシグナル、出来高減少は上昇の勢いが弱い
        - Put/Call Ratio が1.2以上は市場参加者が弱気（逆張りの買いシグナルになる場合も）
        - 機関投資家の大量買いは強いシグナル

        必ず以下のフォーマットのみで回答してください（他の文章は不要）:
        JUDGMENT: buy|sell|skip
        CONFIDENCE: 0.0〜1.0の数値
        VETO: true|false
        VETO_REASON: （veto=trueの場合のみ1行で記載）
      PROMPT

      user_message = <<~MSG
        現在のモメンタム・フローデータ:
        - NAS100価格: #{snapshot.nas100_price}
        - 出来高: #{snapshot.nas100_volume}
        - 1時間モメンタム: #{raw[:momentum_1h] || "データなし"}
        - 4時間モメンタム: #{raw[:momentum_4h] || "データなし"}
        - 日次モメンタム: #{raw[:momentum_1d] || "データなし"}
        - 出来高トレンド（5日平均比）: #{raw[:volume_vs_avg] || "データなし"}
        - Put/Call Ratio: #{raw[:put_call_ratio] || "データなし"}
        - 機関フロー: #{raw[:institutional_flow] || "データなし"}
        - 市場状態: #{snapshot.state}

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
