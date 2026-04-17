class AuditDecisionLedger < ApplicationRecord
  # Phase 32 / 補強6: 監査判断の正式台帳。
  belongs_to :target_ticket, class_name: "TicketLedger"
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true

  enum :decision, {
    approve: 0,
    reject: 1,
    request_changes: 2,
    abstain: 3
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  # §27 で列挙された reason_code の集合。拒否・変更要求・棄権には必ずいずれかを要求する。
  VALID_REASON_CODES = %w[
    approved_no_reservation
    approved_with_follow_up
    low_effectiveness_override
    insufficient_evidence
    scope_violation
    compliance_risk
    security_risk
    cost_runaway
    duplicate_ticket
    timing_mismatch
    other
  ].freeze

  validates :reason_code, presence: true, inclusion: { in: VALID_REASON_CODES }
  validates :audit_role, :scope_level, :decided_at, presence: true

  validate :reason_code_must_match_decision

  scope :non_approvals, -> { where.not(decision: decisions[:approve]) }

  private

  def reason_code_must_match_decision
    if decision_approve? && !%w[approved_no_reservation approved_with_follow_up low_effectiveness_override].include?(reason_code)
      errors.add(:reason_code, "must be an approval code when decision=approve")
    end

    if (decision_reject? || decision_request_changes?) && reason_code&.start_with?("approved_")
      errors.add(:reason_code, "cannot be an approval code when decision is #{decision}")
    end

    # abstain は「拒否権は行使しないが approve もしない」判断なので、approved_* は使わせない。
    if decision_abstain? && reason_code&.start_with?("approved_")
      errors.add(:reason_code, "cannot be an approval code when decision=abstain")
    end
  end
end
