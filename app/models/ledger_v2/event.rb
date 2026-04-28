# LedgerV2::Event — Ledger V2内で起きた副作用・判断・検知結果をすべて記録するモデル。
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_events」
module LedgerV2
  class Event < ApplicationRecord
    self.table_name = "ledger_v2_events"

    belongs_to :run, class_name: "LedgerV2::Run", foreign_key: :run_id

    enum :severity, {
      debug:    0,
      info:     1,
      warning:  2,
      error:    3,
      critical: 4
    }, prefix: true

    validates :run_id,     presence: true
    validates :event_type, presence: true
    validates :severity,   presence: true
    validates :occurred_at, presence: true
  end
end
