class MeetingLedger < ApplicationRecord
  belongs_to :meeting_definition

  enum :meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5,
    quarterly_review: 6,
    annual_plan: 7
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    open: 0,
    closed: 1,
    followup_pending: 2
  }, prefix: true

  validates :meeting_definition, :meeting_key, :meeting_type, :scope_level, :chair, :held_at, :status, presence: true
end
