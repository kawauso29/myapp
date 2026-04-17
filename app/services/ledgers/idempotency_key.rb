module Ledgers
  # Phase 30b / 補強1: Runner が自動採番する idempotency_key の決定論的な
  # 生成ユーティリティ。
  #
  # 同じ「会議定義 + 対象スコープ + 対象日」の組に対して、同じキーを返す。
  # これにより同じ cron スケジュールが二重実行されても DB ユニーク制約で
  # 2 件目が弾かれる（§23.4 / 補強1）。
  module IdempotencyKey
    # @param prefix [String, Symbol] 例: "weekly_dept", "monthly_ops"
    # @param parts [Array<#to_s>] スコープ識別子（service_id、四半期番号、年度など）
    # @param on [Date] 対象日。省略時は当日。
    def self.for_meeting(prefix:, parts: [], on: Date.current)
      segments = [ prefix.to_s, *parts.map(&:to_s), on.iso8601 ].reject(&:blank?)
      segments.join(":")
    end
  end
end
