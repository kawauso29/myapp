module Audits
  # Phase 32 / 補強6: チケット拒否・変更要求時に reason_code 必須の監査判断を記録する。
  class RecordDecision
    Result = Struct.new(:decision, :ticket, keyword_init: true)

    # @param ticket [TicketLedger]
    # @param decision [Symbol] approve / reject / request_changes / abstain
    # @param reason_code [String] `AuditDecisionLedger::VALID_REASON_CODES` のいずれか
    # @param audit_role [String] 拒否権を持つロール名
    # @param source_meeting [MeetingLedger, nil]
    def self.call(**args)
      new(**args).call
    end

    def initialize(ticket:, decision:, reason_code:, audit_role:, auditor: nil, reason_detail: nil,
                   source_meeting: nil, effectiveness_override_score: nil, idempotency_key: nil)
      @ticket = ticket
      @decision = decision.to_sym
      @reason_code = reason_code
      @audit_role = audit_role
      @auditor = auditor
      @reason_detail = reason_detail
      @source_meeting = source_meeting
      @effectiveness_override_score = effectiveness_override_score
      @idempotency_key = idempotency_key
    end

    def call
      AuditDecisionLedger.transaction do
        record = AuditDecisionLedger.create!(
          target_ticket: @ticket,
          decision: @decision,
          reason_code: @reason_code,
          reason_detail: @reason_detail,
          audit_role: @audit_role,
          auditor: @auditor,
          scope_level: resolve_scope_level,
          service_id: @ticket.service_id,
          source_meeting: @source_meeting,
          effectiveness_override_score: @effectiveness_override_score,
          idempotency_key: @idempotency_key,
          decided_at: Time.current
        )

        apply_decision_to_ticket!
        Result.new(decision: record, ticket: @ticket.reload)
      end
    end

    private

    def resolve_scope_level
      case @ticket.scope_level
      when "company", :company then :company
      when "portfolio", :portfolio then :portfolio
      else :service
      end
    end

    def apply_decision_to_ticket!
      case @decision
      when :approve
        @ticket.update!(status: :approved) unless @ticket.status_approved?
      when :reject
        @ticket.update!(status: :cancelled) unless @ticket.status_cancelled?
      when :request_changes
        @ticket.update!(status: :draft) if @ticket.status_waiting_review?
      end
    end
  end
end
