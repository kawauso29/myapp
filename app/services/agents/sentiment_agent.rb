# センチメントエージェント
#
# 担当: 市場センチメント・ニュースの判断
# 主な判断要素:
#   - ニュースヘッドライン（ポジティブ/ネガティブ）
#   - Fear & Greed Index
#   - SNS・フォーラムのセンチメント
#   - アナリストコンセンサス

module Agents
  class SentimentAgent < BaseAgent
    private

    def agent_type
      "sentiment"
    end

    def analyze(snapshot)
      raw = snapshot.raw_data&.symbolize_keys || {}

      system_prompt = <<~PROMPT
        あなたはNAS100（ナスダック100）専門の市場センチメント分析エージェントです。
        ニュース・センチメント指標を分析し、売買判断を行ってください。

        判断ルール:
        - Fear & Greed Index が10以下（Extreme Fear）は逆張り買いの機会の可能性
        - Fear & Greed Index が90以上（Extreme Greed）は過熱感あり、売りまたはskip
        - 主要ニュースがネガティブ（Fed引き締め・景気後退・信用不安など）の場合は慎重に
        - センチメントが極端に一方向の場合は逆張りを検討

        必ず以下のフォーマットで回答してください:
        JUDGMENT: buy|sell|skip
        CONFIDENCE: 0.0〜1.0の数値
        VETO: true|false（センチメントが明確に逆サインの場合はtrue）
        VETO_REASON: （vetoがtrueの場合のみ記載）
        REASONING: 判断の根拠を日本語で記載
      PROMPT

      user_message = <<~MSG
        現在のセンチメントデータ:
        - Fear & Greed Index: #{raw[:fear_greed_index] || "データなし"}
        - 主要ニュースヘッドライン: #{raw[:news_headlines] || "データなし"}
        - ニュースセンチメントスコア（-1〜+1）: #{raw[:news_sentiment_score] || "データなし"}
        - Twitter/SNSセンチメント: #{raw[:social_sentiment] || "データなし"}
        - アナリストコンセンサス: #{raw[:analyst_consensus] || "データなし"}
        - 市場状態: #{snapshot.state}

        センチメントの観点からNAS100の売買判断を行ってください。
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
