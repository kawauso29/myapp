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
    annual_plan: "annual_plan",
    improvement: "improvement"
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

  # 補強13: 外部依存 SLA 超過時の自動措置
  enum :sla_breach_action, {
    auto_escalate: 0,
    auto_reject: 1,
    audit_open: 2
  }, prefix: true

  validates :ticket_type, :title, :scope_level, :status, :priority, presence: true
  validates :effectiveness_score,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true
  validates :effectiveness_sample_size,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validate :linked_kpis_not_empty
  validate :sla_breached_at_requires_deadline

  scope :overdue_candidates, -> { where(status: :waiting_review).where("due_date < ?", Date.current) }
  scope :sla_breached, -> { where.not(sla_breached_at: nil) }
  scope :sla_approaching, ->(within: 1.day) {
    where(sla_breached_at: nil)
      .where.not(sla_deadline: nil)
      .where(sla_deadline: Time.current..(Time.current + within))
  }

  before_save :set_resolved_at, if: :will_save_change_to_status?
  before_save :mark_sla_breach, if: :sla_deadline?

  # 補強10: improvement 起票前に類似 pattern の過去 effectiveness_score 平均を返す。
  # サンプルサイズ不足（< 3）や該当なしは nil を返し、呼び出し側で扱いを決める。
  def self.effectiveness_for_pattern(pattern_key, min_sample: 3)
    return nil if pattern_key.blank?

    rows = ticket_type_improvement
           .where(improvement_pattern_key: pattern_key)
           .where.not(effectiveness_score: nil)
    return nil if rows.size < min_sample

    rows.average(:effectiveness_score)&.to_f
  end

  def sla_breached?
    sla_breached_at.present?
  end

  private

  def set_resolved_at
    return unless status_approved? || status_cancelled?

    self.resolved_at = Time.current
  end

  def linked_kpis_not_empty
    return unless linked_kpis.blank?

    errors.add(:linked_kpis, "can't be blank")
  end

  def sla_breached_at_requires_deadline
    return if sla_breached_at.blank?
    return if sla_deadline.present?

    errors.add(:sla_breached_at, "requires sla_deadline to be set")
  end

  def mark_sla_breach
    return if sla_breached_at.present?
    return if sla_deadline.blank? || sla_deadline >= Time.current

    self.sla_breached_at = Time.current
  end
end
