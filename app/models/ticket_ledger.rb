class TicketLedger < ApplicationRecord
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2
  }, prefix: true

  enum :source_meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5
  }, prefix: true

  enum :ticket_type, {
    operations: "operations",
    audit: "audit",
    ops: "ops",
    quarterly_review: "quarterly_review",
    annual_plan: "annual_plan"
  }, prefix: true

  enum :status, {
    draft: 0,
    approved: 1,
    planned: 2,
    executing: 3,
    waiting_review: 4,
    completed: 5,
    cancelled: 6,
    overdue: 7
  }, prefix: true

  enum :due_cycle, {
    daily: 0,
    weekly: 1,
    monthly: 2,
    quarterly: 3,
    annual: 4,
    long_term: 5
  }, prefix: true

  enum :escalation_to, {
    monthly: 0,
    quarterly: 1,
    annual: 2,
    long_term: 3
  }, prefix: true

  enum :priority, {
    low: 0,
    medium: 1,
    high: 2
  }, prefix: true

  validates :ticket_type, :title, :scope_level, :status, :priority, presence: true
  validate :linked_kpis_not_empty
  scope :overdue_candidates, -> { where(status: :waiting_review).where("due_date < ?", Date.current) }

  before_save :set_resolved_at, if: :will_save_change_to_status?

  private

  def set_resolved_at
    return unless status_approved? || status_cancelled?

    self.resolved_at = Time.current
  end

  def linked_kpis_not_empty
    return unless linked_kpis.blank?

    errors.add(:linked_kpis, "can't be blank")
  end
end
