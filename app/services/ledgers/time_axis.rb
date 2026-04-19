module Ledgers
  # 圧縮経営時間軸の正本（設計書 §11 / `thu_apr_16_2026_自律運営型ai企業体の設計.md` line 2309）
  #
  # 4年（長期経営）= 28日に圧縮する固定値で、すべての Ledger 系 cron / Runner /
  # idempotency_key の time slot はこの値を起点に計算する。
  #
  #   daily       = 30分
  #   weekly      = 4時間
  #   monthly     = 12時間
  #   quarterly   = 2日   (= 48時間)
  #   annual      = 7日
  #   long_term   = 28日  (= 4年相当)
  #
  # Phase 44a: サービス固有の設定は `ServiceTimeAxisSetting` テーブルに DB 化。
  # DB に設定がなければこのデフォルト定数にフォールバックする。
  module TimeAxis
    INTERVALS = {
      daily: 30.minutes,
      weekly: 4.hours,
      monthly: 12.hours,
      quarterly: 2.days,
      annual: 7.days,
      long_term: 28.days
    }.freeze

    CADENCES = INTERVALS.keys.freeze

    # @param cadence [Symbol, String]
    # @param service_id [String, nil] サービス固有の設定を参照する場合に指定
    # @return [ActiveSupport::Duration]
    def self.interval_for(cadence, service_id: nil)
      cadence_sym = cadence.to_sym
      raise ArgumentError, "Unknown cadence: #{cadence.inspect} (allowed: #{CADENCES.join(', ')})" unless CADENCES.include?(cadence_sym)

      # Phase 44a: DB にサービス固有の設定があればそちらを優先
      if service_id.present?
        db_interval = ServiceTimeAxisSetting.interval_for(service_id: service_id, cadence: cadence_sym)
        return db_interval if db_interval
      end

      INTERVALS.fetch(cadence_sym)
    end

    # 与えられた時刻を cadence の interval で切り捨てた "slot 開始時刻" を返す。
    #
    # 例: cadence: :weekly (4h), at: 2026-04-19 13:30 UTC → 2026-04-19 12:00 UTC
    # 同じ slot に属する複数回の Runner 起動は同じ idempotency_key を生成し、
    # 2回目以降は DB ユニーク制約で弾かれる（補強1）。
    #
    # @param cadence [Symbol, String]
    # @param at [Time, ActiveSupport::TimeWithZone]
    # @return [Time] UTC
    def self.slot_start(cadence, at: Time.current)
      interval_seconds = interval_for(cadence).to_i
      time = at.respond_to?(:to_time) ? at.to_time : at
      Time.at((time.to_i / interval_seconds) * interval_seconds).utc
    end

    # idempotency_key の trailing 部分に使う slot 識別子（ISO8601 文字列）。
    #
    # @param cadence [Symbol, String]
    # @param at [Time, ActiveSupport::TimeWithZone]
    # @return [String]
    def self.slot_token(cadence, at: Time.current)
      slot_start(cadence, at: at).iso8601
    end

    # ticket の due_date 用ヘルパー。`due_date` カラムは date 型のため、
    # サブ日 cadence（daily/weekly/monthly）も含めて常に Date を返す。
    #
    #   :weekly (4h) を 12:00 に呼ぶと → today、22:00 に呼ぶと → tomorrow
    #   :quarterly (2d) → +2 days、:annual (7d) → +7 days
    #
    # @param cadence [Symbol, String]
    # @param from [Time, Date, nil]
    # @return [Date]
    def self.due_date_for(cadence, from: nil)
      from_time =
        case from
        when nil then Time.current
        when Date then from.in_time_zone
        else from
        end
      (from_time + interval_for(cadence)).to_date
    end
  end
end
