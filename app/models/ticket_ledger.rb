class TicketLedger < ApplicationRecord
  # Phase 30c / 補強3: すべての起票は発生元の会議（またはシステム自動化会議）に紐付く必要がある。
  belongs_to :source_meeting, class_name: "MeetingLedger"

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

  # Phase 36 / §13: 28日運営レーン
  enum :operating_lane, {
    immediate: 0,
    weekly_improvement: 1,
    monthly_ops: 2,
    quarterly_review_lane: 3
  }, prefix: true

  # §17 / Phase 35: 起票カテゴリ 11 種（+ 既存の運用由来 3 種を後方互換として残す）
  enum :ticket_type, {
    # 旧来（後方互換）
    operations: "operations",
    ops: "ops",
    quarterly_review: "quarterly_review",
    annual_plan: "annual_plan",
    service_pivot: "service_pivot",
    # §17 の 11 種
    initiative: "initiative",             # 1. 施策起票
    investigation: "investigation",       # 2. 調査起票
    audit: "audit",                       # 3. 監査起票
    hr: "hr",                             # 4. 人事起票
    customer_notice: "customer_notice",   # 5. 顧客案内起票
    tech_record: "tech_record",           # 6. 技術記録起票
    org_change: "org_change",             # 7. 組織起票
    exec_plan: "exec_plan",               # 8. 経営起票
    service_launch: "service_launch",     # 9. 新規サービス起票
    service_shutdown: "service_shutdown", # 10. サービス縮小 / 廃止起票
    service_merge: "service_merge",       # 11. サービス統合起票
    improvement: "improvement"            # 10 + effectiveness ループ（§33.3 補強10）
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

  # §32-5 / §31: リスクレベル（GitHub フロー差分制御に使用）
  enum :risk_level, {
    low: 0,
    medium: 1,
    high: 2
  }, prefix: true

  validates :ticket_type, :title, :scope_level, :status, :priority, presence: true
  validates :effectiveness_score,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true
  validates :effectiveness_sample_size,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  # 補強1: 同一イベントの二重書き込みを DB レベルで防ぐ。
  # 値は任意（既存呼び出しを壊さない）だが、設定時は一意である必要がある。
  validates :idempotency_key, uniqueness: true, allow_nil: true
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

    improvement_tickets = ticket_type_improvement
                            .where(improvement_pattern_key: pattern_key)
                            .where.not(effectiveness_score: nil)
    return nil if improvement_tickets.size < min_sample

    improvement_tickets.average(:effectiveness_score)&.to_f
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
