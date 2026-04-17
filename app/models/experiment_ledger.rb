class ExperimentLedger < ApplicationRecord
  belongs_to :source_ticket, class_name: "TicketLedger", optional: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2
  }, prefix: true

  enum :status, {
    active: 0,
    continued: 1,
    withdrawn: 2,
    expired: 3
  }, prefix: true

  validates :service_id, :hypothesis, :deadline, :status, presence: true
  validate :kpi_targets_not_empty

  scope :active_experiments, -> { status_active.where("deadline >= ?", Date.current) }
  scope :expired_candidates, -> { status_active.where("deadline < ?", Date.current) }

  # R4: 期限到達時に KPI 達成状況を踏まえて自動判定する。
  def decide!(decision, reason: nil)
    update!(
      status: decision,
      auto_decision: decision.to_s,
      decided_at: Time.current,
      decision_reason: reason
    )
  end

  def expired?
    status_active? && deadline < Date.current
  end

  private

  def kpi_targets_not_empty
    return unless kpi_targets.blank?

    errors.add(:kpi_targets, "can't be blank")
  end
end
