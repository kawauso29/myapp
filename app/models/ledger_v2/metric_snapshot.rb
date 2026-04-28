# LedgerV2::MetricSnapshot — KPI・システム指標のスナップショットモデル。
#
# 重要ルール:
# - Snapshot は観測事実として保存する（判断は Event / Ticket に分ける）
# - Snapshot 作成だけでは Ticket を作らない
# - 異常検知は LedgerV2::DetectMetricAnomalies（Ticket 9）が担当する
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_metric_snapshots」
module LedgerV2
  class MetricSnapshot < ApplicationRecord
    self.table_name = "ledger_v2_metric_snapshots"

    # period: 集計粒度
    enum :period, {
      hourly: 0,
      daily:  1,
      weekly: 2
    }, prefix: true

    belongs_to :created_by_run, class_name: "LedgerV2::Run",
                                foreign_key: :created_by_run_id, optional: true

    validates :metric_name,  presence: true
    validates :value,        presence: true
    validates :period,       presence: true
    validates :measured_at,  presence: true
  end
end
