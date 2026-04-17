class CustomerFeedbackLedger < ApplicationRecord
  # Phase 39 / §32.1: 顧客フィードバック台帳。
  belongs_to :linked_ticket, class_name: "TicketLedger", optional: true

  enum :source, {
    in_app: 0,
    slack: 1,
    email: 2,
    nps: 3,
    external_review: 4,
    manual: 5
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    new_feedback: 0,
    categorized: 1,
    escalated: 2,
    closed: 3
  }, prefix: true

  validates :source, :scope_level, :raw_text, :received_at, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true

  scope :pending_triage, -> { status_new_feedback }
end
