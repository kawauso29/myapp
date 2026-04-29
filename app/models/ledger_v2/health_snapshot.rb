# LedgerV2::HealthSnapshot — Ledger V2 自体の健全性を記録するモデル。
#
# 重要ルール:
# - Ledger V2 自身を評価対象にする（v1 や外部システムではない）
# - Artifact 採用率と Ticket ノイズ率が最重要指標
# - HealthSnapshot の内容を AI が自律的に判断してアクションしない
#   （人間が見て昇格判断する — 運用ルール §14）
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_health_snapshots」
module LedgerV2
  class HealthSnapshot < ApplicationRecord
    self.table_name = "ledger_v2_health_snapshots"

    # 集計粒度
    enum :period, {
      daily:  0,
      weekly: 1
    }, prefix: true

    validates :period,                             presence: true
    validates :measured_at,                        presence: true
    validates :ticket_noise_rate,                  presence: true,
              numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :artifact_acceptance_rate,           presence: true,
              numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :runner_failure_rate,                presence: true,
              numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :unresolved_ticket_age_avg,          presence: true,
              numericality: { greater_than_or_equal_to: 0.0 }
    validates :human_intervention_rate,            presence: true,
              numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :kpi_improvement_after_ticket_rate,  presence: true,
              numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
    validates :stop_trigger_count,        presence: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :duplicate_prevented_count, presence: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :pending_review_count,      presence: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :open_ticket_count,         presence: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # 最新スナップショットを period 別に取得する。
    scope :latest_per_period, -> {
      where(measured_at: group(:period).maximum(:measured_at).values)
    }
  end
end
