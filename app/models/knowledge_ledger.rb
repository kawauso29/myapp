class KnowledgeLedger < ApplicationRecord
  # Phase 37 / §20: 知識台帳（ADR / Runbook / Incident / Deploy 記録）。
  belongs_to :supersedes, class_name: "KnowledgeLedger", optional: true
  has_many :supersessions, class_name: "KnowledgeLedger", foreign_key: :supersedes_id, dependent: :restrict_with_error
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true
  belongs_to :source_ticket, class_name: "TicketLedger", optional: true

  enum :kind, {
    adr: 0,
    runbook: 1,
    incident: 2,
    deploy: 3
  }, prefix: true

  enum :status, {
    draft: 0,
    accepted: 1,
    superseded: 2,
    archived: 3
  }, prefix: true

  validates :kind, :title, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true

  scope :active_adrs, -> { kind_adr.status_accepted }
  scope :active_runbooks, -> { kind_runbook.status_accepted }
end
