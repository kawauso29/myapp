class StopLedger < ApplicationRecord
  # Phase 33 / 補強7: 自動停止台帳。§18 の「停止条件が成立した」事実を 1 レコードに記録。
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true
  belongs_to :source_ticket, class_name: "TicketLedger", optional: true

  enum :trigger_type, {
    kpi_breach: 0,
    error_spike: 1,
    cost_runaway: 2,
    security_incident: 3,
    compliance_violation: 4,
    manual_escalation: 5
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    active: 0,
    lifted: 1,
    escalated: 2
  }, prefix: true

  validates :trigger_type, :scope_level, :status, :started_at, presence: true
  validate :lifted_at_is_after_started_at
  validate :lifted_fields_required_when_lifted

  scope :currently_active, -> { status_active }
  scope :active_for, ->(scope_level:, service_id: nil) {
    rel = status_active.where(scope_level: scope_levels[scope_level])
    rel = rel.where(service_id: service_id) if service_id
    rel
  }

  # 停止を解除する。`lifted_by` と `lift_reason` を必ず指定する。
  def lift!(by:, reason:)
    update!(status: :lifted, lifted_at: Time.current, lifted_by: by, lift_reason: reason)
  end

  private

  def lifted_at_is_after_started_at
    return if lifted_at.blank? || started_at.blank?
    return if lifted_at >= started_at

    errors.add(:lifted_at, "must be greater than or equal to started_at")
  end

  # `status: :lifted` の行は必ず lifted_at / lifted_by / lift_reason を伴う。
  # `lift!` 以外の経路（直接 update 等）で空のまま lifted 化されるのを防ぐ。
  def lifted_fields_required_when_lifted
    return unless status_lifted?

    errors.add(:lifted_at, "can't be blank when status=lifted") if lifted_at.blank?
    errors.add(:lifted_by, "can't be blank when status=lifted") if lifted_by.blank?
    errors.add(:lift_reason, "can't be blank when status=lifted") if lift_reason.blank?
  end
end
