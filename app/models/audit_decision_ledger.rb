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

  # Phase 44e / §33.2 補強9: 非承認判断時に reason_detail（詳細理由テキスト）を必須化する。
  # true の場合、reject / request_changes / abstain で reason_detail が blank だと
  # バリデーションエラーにする（`skip_audit_reason_detail = true` で bypass 可能）。
  # デフォルト OFF。`ENFORCE_AUDIT_REASON=1` で段階的に有効化する。
  class_attribute :enforce_audit_reason, instance_accessor: false, default: false

  attr_accessor :skip_audit_reason_detail

  validates :reason_code, presence: true, inclusion: { in: VALID_REASON_CODES }
  validates :audit_role, :scope_level, :decided_at, presence: true

  validate :reason_code_must_match_decision
  validate :reason_detail_required_when_enforced

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

  # Phase 44e: enforce_audit_reason が有効な場合、非承認判断には reason_detail を必須化する。
  def reason_detail_required_when_enforced
    return unless self.class.enforce_audit_reason
    return if skip_audit_reason_detail
    return if decision_approve?
    return if reason_detail.present?

    errors.add(:reason_detail, "is required for non-approval decisions when enforce_audit_reason is enabled")
  end
end
