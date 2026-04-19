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
    # @param cadence [Symbol, String, nil] 圧縮時間軸の cadence（:daily/:weekly/:monthly/
    #   :quarterly/:annual/:long_term）。指定すると trailing は `Date#iso8601` ではなく
    #   `Ledgers::TimeAxis.slot_token` の戻り値（slot 開始時刻）になる。
    #   圧縮スケジュール（例: weekly = 4 時間ごと）で同日中に複数回 Runner が
    #   起動するケースで、同 slot 内の重複起動だけを冪等弾きするために使う。
    def self.for_meeting(prefix:, parts: [], on: nil, cadence: nil)
      trailing = if cadence
        at = case on
        when nil then Time.current
        when Date then on.in_time_zone
        else on
        end
        Ledgers::TimeAxis.slot_token(cadence, at: at)
      else
        (on || Date.current).iso8601
      end
      segments = [ prefix.to_s, *parts.map(&:to_s), trailing ].reject(&:blank?)
      segments.join(":")
    end
  end
end
