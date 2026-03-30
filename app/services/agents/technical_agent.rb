# テクニカルエージェント
#
# 担当: チャートパターン・テクニカル指標の判断
# 主な判断要素:
#   - EMA（20/50/200）のクロス・配置
#   - RSI（過買い・過売り）
#   - MACD
#   - サポート/レジスタンスとの距離
#   - ボリンジャーバンド

module Agents
  class TechnicalAgent < BaseAgent
    private

    def agent_type
      "technical"
    end

    def analyze(snapshot)
      raw = snapshot.raw_data&.symbolize_keys || {}

      system_prompt = <<~PROMPT
        あなたはNAS100（ナスダック100）専門のテクニカルアナリストです。
        与えられたテクニカル指標を分析し、NAS100の売買判断を行ってください。

        判断ルール:
        - EMA200より上かつEMA20がEMA50を上抜けている場合は買い優勢
        - RSI70以上は過買い（売りまたはskip）、RSI30以下は過売り（買い優勢）
        - MACDがシグナルラインを上抜けた直後は買いシグナル
        - サポートに近い場合は買い、レジスタンスに近い場合は売りまたはskip
        - ボリンジャーバンド収縮中はレンジ、拡張時はトレンド

        必ず以下のフォーマットで回答してください:
        JUDGMENT: buy|sell|skip
        CONFIDENCE: 0.0〜1.0の数値
        VETO: true|false（テクニカル的に明確な逆サインがある場合はtrue）
        VETO_REASON: （vetoがtrueの場合のみ記載）
        REASONING: 判断の根拠を日本語で記載
      PROMPT

      user_message = <<~MSG
        現在のテクニカル指標:
        - NAS100価格: #{snapshot.nas100_price}
        - EMA20: #{raw[:ema20] || "データなし"}
        - EMA50: #{raw[:ema50] || "データなし"}
        - EMA200: #{raw[:ema200] || "データなし"}
        - EMA200より上か: #{raw[:price_above_ema200] || "データなし"}
        - RSI(14): #{raw[:rsi14] || "データなし"}
        - MACD: #{raw[:macd] || "データなし"}
        - MACDシグナル: #{raw[:macd_signal] || "データなし"}
        - ADX: #{raw[:adx] || "データなし"}
        - ボリンジャー上限: #{raw[:bb_upper] || "データなし"}
        - ボリンジャー下限: #{raw[:bb_lower] || "データなし"}
        - 直近サポート: #{raw[:support_level] || "データなし"}
        - 直近レジスタンス: #{raw[:resistance_level] || "データなし"}
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
