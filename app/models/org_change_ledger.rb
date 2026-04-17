class OrgChangeLedger < ApplicationRecord
  # Phase 38 / §19: 組織再編台帳（スケルトン）。
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true
  belongs_to :source_ticket, class_name: "TicketLedger", optional: true

  enum :change_type, {
    role_create: 0,
    role_retire: 1,
    team_split: 2,
    team_merge: 3,
    reporting_change: 4
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    proposed: 0,
    approved: 1,
    in_effect: 2,
    rolled_back: 3
  }, prefix: true

  validates :change_type, :scope_level, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true
end
