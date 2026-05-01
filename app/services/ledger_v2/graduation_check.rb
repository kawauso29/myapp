# LedgerV2::GraduationCheck — v2 Kernel が「卒業」して Layer C 接続に進んでよいか判定する。
#
# 設計方針（徹底的にシンプル）:
# - 7 つの卒業基準を 1 つの定数 CRITERIA に宣言する。これがそのまま単一の正本。
# - 「現在値の取り方」と「しきい値判定」だけを行う。副作用ゼロ。
# - 新規モデル・新規 migration は作らない。HealthSnapshot と既存集計だけを参照する。
#
# 使い方:
#   results = LedgerV2::GraduationCheck.call    # => [Result, ...]
#   LedgerV2::GraduationCheck.all_pass?         # => true / false
#
# しきい値の出典: docs/projects/ledger-v2-migration.md「v2 卒業基準」
module LedgerV2
  module GraduationCheck
    Result = Struct.new(:key, :label, :value, :op, :threshold, :ok, keyword_init: true) do
      def ok?
        ok
      end
    end

    # 7 つの卒業基準。
    # op はそのまま `value.public_send(op, threshold)` で評価する（>=, <=, ==）。
    CRITERIA = [
      { key: :ticket_noise_rate,             label: "Ticket ノイズ率（rejected/duplicate 比率）", op: :<=, threshold: 0.30 },
      { key: :artifact_acceptance_rate,      label: "Artifact 採用率",                              op: :>=, threshold: 0.50 },
      { key: :runner_failure_rate,           label: "Runner 失敗率",                                op: :<=, threshold: 0.10 },
      { key: :stop_trigger_count_active,     label: "現在 active な StopCondition",                op: :==, threshold: 0    },
      { key: :duplicate_prevented_total,     label: "重複防止が一度でも作動した実績",              op: :>=, threshold: 1    },
      { key: :health_snapshot_count,         label: "HealthSnapshot 件数（圧縮日 = 30分毎）",      op: :>=, threshold: 7    },
      { key: :pending_review_count,          label: "レビュー待ち件数（詰まり防止）",              op: :<=, threshold: 20   }
    ].freeze

    # @return [Array<Result>] 7 基準の判定結果
    def self.call
      snapshot = latest_daily_snapshot
      values   = current_values(snapshot)

      CRITERIA.map do |c|
        v = values[c[:key]]
        Result.new(
          key:       c[:key],
          label:     c[:label],
          value:     v,
          op:        c[:op],
          threshold: c[:threshold],
          ok:        compare(v, c[:op], c[:threshold])
        )
      end
    end

    # @return [Boolean] 全 7 基準を満たしているか
    def self.all_pass?
      call.all?(&:ok?)
    end

    # --- 内部実装（private） ---

    def self.latest_daily_snapshot
      LedgerV2::HealthSnapshot
        .where(period: LedgerV2::HealthSnapshot.periods[:daily])
        .order(measured_at: :desc)
        .first
    end
    private_class_method :latest_daily_snapshot

    # 各基準の「現在値」を 1 か所にまとめる。
    # snapshot がまだ無い段階でも安全に評価できるようフォールバックを用意する。
    def self.current_values(snapshot)
      {
        ticket_noise_rate:        snapshot&.ticket_noise_rate        || 0.0,
        artifact_acceptance_rate: snapshot&.artifact_acceptance_rate || 0.0,
        runner_failure_rate:      snapshot&.runner_failure_rate      || 0.0,
        stop_trigger_count_active: LedgerV2::StopCondition.active_conditions.count,
        duplicate_prevented_total: LedgerV2::Run.sum(:duplicate_prevented_count).to_i,
        health_snapshot_count:     LedgerV2::HealthSnapshot.count,
        pending_review_count:      snapshot&.pending_review_count    || LedgerV2::Artifact.awaiting_review.count
      }
    end
    private_class_method :current_values

    def self.compare(value, op, threshold)
      return false if value.nil?

      value.public_send(op, threshold)
    end
    private_class_method :compare
  end
end
