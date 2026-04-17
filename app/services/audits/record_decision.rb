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
          reason_detail: resolved_reason_detail,
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

    # Phase 40: reason_detail が未指定で LLM gateway が有効な場合、LLM で判断根拠の
    # 補足文を生成する。gateway 無効 / 失敗時は元の値（nil 可）を返す。
    def resolved_reason_detail
      return @reason_detail if @reason_detail.present?
      return nil unless Llm::Gateway.enabled?

      prompt = <<~PROMPT
        以下のチケットに対する監査判断を 1 文（日本語・80〜200 文字）で
        説明してください。reason_code の意味を簡潔に添え、次アクションを示してください。

        ticket_id: #{@ticket.id}
        ticket_type: #{@ticket.ticket_type}
        title: #{@ticket.title}
        decision: #{@decision}
        reason_code: #{@reason_code}
        scope_level: #{@ticket.scope_level}
        service_id: #{@ticket.service_id}

        出力は補足文のみ。前置きや引用符は不要。
      PROMPT

      result = Llm::Gateway.call(purpose: :audit, prompt: prompt, max_tokens: 400)
      return nil unless result.success?

      result.text.to_s.strip[0, 1000]
    end

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
