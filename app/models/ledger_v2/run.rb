# LedgerV2::Run — すべてのRunner実行を記録する中心モデル。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_runs」
module LedgerV2
  class Run < ApplicationRecord
    self.table_name = "ledger_v2_runs"

    has_many :events, class_name: "LedgerV2::Event", foreign_key: :run_id, dependent: :destroy

    enum :status, {
      pending:   0,
      running:   1,
      success:   2,
      failed:    3,
      skipped:   4,
      blocked:   5,
      cancelled: 6
    }, prefix: true

    enum :trigger_type, {
      schedule: 0,
      manual:   1,
      console:  2,
      job:      3,
      test:     4,
      webhook:  5,
      system:   6
    }, prefix: true

    validates :runner_name,  presence: true
    validates :status,       presence: true
    validates :trigger_type, presence: true

    validates :created_ticket_count,      numericality: { greater_than_or_equal_to: 0 }
    validates :updated_ticket_count,      numericality: { greater_than_or_equal_to: 0 }
    validates :created_artifact_count,    numericality: { greater_than_or_equal_to: 0 }
    validates :created_event_count,       numericality: { greater_than_or_equal_to: 0 }
    validates :duplicate_prevented_count, numericality: { greater_than_or_equal_to: 0 }
  end
end
