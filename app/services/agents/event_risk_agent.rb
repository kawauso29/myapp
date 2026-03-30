# イベントリスクエージェント
#
# 担当: 経済指標・イベントリスクの判断（最も重要な安全弁の1つ）
# 主な判断要素:
#   - 重要指標の発表スケジュール（CPI/雇用統計/FOMC/GDP等）
#   - Mag7企業の決算発表
#   - 地政学的リスク
#   - 連休・市場休場日
#
# このエージェントは「見送り推奨」が多くなることが正しい動作。

module Agents
  class EventRiskAgent < BaseAgent
    # 拒否権を発動するイベント種別
    VETO_EVENT_TYPES = %w[
      fomc cpi pce employment_report gdp
      mag7_earnings fed_speech market_holiday
    ].freeze

    private

    def agent_type = "event_risk"
    def llm_model  = ENV.fetch("EVENT_RISK_MODEL", "gpt-5.4-nano")

    def analyze(snapshot)
      raw = snapshot.raw_data&.symbolize_keys || {}

      # まずロジックベースで危険イベントをチェック（APIコスト節約）
      quick_veto = check_quick_veto(raw)
      return quick_veto if quick_veto

      system_prompt = <<~PROMPT
        あなたはNAS100（ナスダック100）専門のイベントリスク管理エージェントです。
        経済指標や市場イベントのリスクを評価し、売買判断を行ってください。

        最重要ルール（これらに該当する場合は必ずVETO=true、JUDGMENT=skip）:
        - FOMC（政策金利発表日）
        - 米国CPI発表の前後2時間
        - 雇用統計（NFP）発表の前後2時間
        - MAG7（Apple/Microsoft/Google/Amazon/Meta/Nvidia/Tesla）の決算発表日
        - 重要な地政学的イベント発生中

        これらに該当しない場合はイベントリスクの程度を評価してください。

        必ず以下のフォーマットのみで回答してください（他の文章は不要）:
        JUDGMENT: buy|sell|skip
        CONFIDENCE: 0.0〜1.0の数値
        VETO: true|false
        VETO_REASON: （veto=trueの場合のみ1行で記載）
      PROMPT

      user_message = <<~MSG
        現在のイベント情報:
        - 本日の重要イベント: #{raw[:today_events] || "なし"}
        - 直近2時間以内の発表: #{raw[:upcoming_releases] || "なし"}
        - MAG7決算: #{raw[:mag7_earnings_today] ? "あり" : "なし"}
        - FOMC当日: #{raw[:fomc_today] ? "はい" : "いいえ"}
        - 地政学リスクレベル: #{raw[:geopolitical_risk] || "低"}
        - 翌営業日イベント: #{raw[:tomorrow_events] || "なし"}

        イベントリスクの観点からNAS100の売買判断を行ってください。
      MSG

      response = call_llm(system_prompt: system_prompt, user_message: user_message)
      return fallback_result("Claude APIレスポンスなし") if response.blank?

      parse_ai_response(response)
    end

    # APIを叩く前のルールベース拒否権チェック
    def check_quick_veto(raw)
      if raw[:fomc_today]
        return AgentResult.new(
          judgment:    "skip",
          confidence:  1.0,
          reasoning:   "FOMC当日のため不執行",
          veto:        true,
          veto_reason: "FOMC_TODAY"
        )
      end

      if raw[:high_impact_event_soon]
        return AgentResult.new(
          judgment:    "skip",
          confidence:  1.0,
          reasoning:   "重要指標発表前後2時間のため不執行",
          veto:        true,
          veto_reason: "HIGH_IMPACT_EVENT_SOON"
        )
      end

      if raw[:mag7_earnings_today]
        return AgentResult.new(
          judgment:    "skip",
          confidence:  1.0,
          reasoning:   "MAG7決算発表日のため不執行",
          veto:        true,
          veto_reason: "MAG7_EARNINGS_TODAY"
        )
      end

      nil
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
