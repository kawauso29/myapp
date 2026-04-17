module Feedback
  # Phase 39 / §32.1: 顧客フィードバックを受け取って台帳化し、必要なら
  # improvement / investigation ticket へ昇格させる。
  class Intake
    Result = Struct.new(:feedback, :escalated_ticket, keyword_init: true)

    def self.submit(**args)
      new(**args).submit
    end

    def initialize(source:, raw_text:, scope_level: :service, service_id: "ai_sns",
                   submitted_by: nil, categorization: {}, idempotency_key: nil, received_at: nil)
      @source = source.to_sym
      @raw_text = raw_text.to_s
      @scope_level = scope_level.to_sym
      @service_id = service_id
      @submitted_by = submitted_by
      @categorization = categorization || {}
      @idempotency_key = idempotency_key
      @received_at = received_at || Time.current
    end

    def submit
      CustomerFeedbackLedger.transaction do
        feedback = CustomerFeedbackLedger.create!(
          source: @source,
          scope_level: @scope_level,
          service_id: @service_id,
          raw_text: @raw_text,
          submitted_by: @submitted_by,
          status: initial_status,
          categorization: @categorization,
          idempotency_key: @idempotency_key,
          received_at: @received_at
        )

        ticket = maybe_escalate!(feedback)
        Result.new(feedback: feedback, escalated_ticket: ticket)
      end
    end

    private

    # 分類が sentiment=negative かつ severity=high の場合は即時 escalate
    def initial_status
      if high_severity?
        :escalated
      elsif @categorization.present?
        :categorized
      else
        :new_feedback
      end
    end

    def high_severity?
      sentiment = @categorization["sentiment"] || @categorization[:sentiment]
      severity = @categorization["severity"] || @categorization[:severity]
      # 外部入力の表記ゆれ（"Negative" / "HIGH" 等）を吸収するため小文字比較する。
      sentiment.to_s.downcase == "negative" && severity.to_s.downcase == "high"
    end

    def maybe_escalate!(feedback)
      return nil unless high_severity?

      meeting = Ledgers::SystemMeetingProvider.for(kind: "customer_feedback_intake")
      ticket = TicketLedger.create!(
        ticket_type: :investigation,
        title: "Customer feedback escalation ##{feedback.id}",
        scope_level: map_scope_level,
        service_id: @service_id,
        source_meeting_type: :incident,
        source_meeting: meeting,
        operating_lane: :immediate,
        linked_kpis: [ "kpi:customer_feedback" ],
        linked_artifacts: [],
        priority: :high,
        status: :waiting_review,
        assignee: "feedback_intake",
        due_date: Date.current + 3.days,
        due_cycle: :weekly,
        risk_level: :high
      )
      feedback.update!(linked_ticket: ticket)
      ticket
    end

    def map_scope_level
      case @scope_level
      when :portfolio then :portfolio
      when :company, :cross_service then :company
      else :service
      end
    end
  end
end
