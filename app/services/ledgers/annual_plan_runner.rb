module Ledgers
  class AnnualPlanRunner
    DEFAULT_ASSIGNEE = "annual_plan_runner".freeze

    def self.call(present_roles: nil)
      new(present_roles:).call
    end

    def initialize(present_roles: nil)
      @present_roles = present_roles
    end

    def call
      definition = meeting_definition!
      preflight = Ledgers::PreflightValidator.call(definition:, present_roles: @present_roles)
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        chair: definition.chair_role,
        participants: preflight.participants,
        role_fill_rate: preflight.role_fill_rate,
        held_at: Time.current,
        status: :open,
        idempotency_key: Ledgers::IdempotencyKey.for_meeting(
          prefix: "annual_plan",
          parts: [ "fy#{Date.current.year}" ],
          cadence: :annual
        )
      )
      @current_meeting_id = meeting.id

      metrics = summary_metrics
      ticket = TicketLedger.create!(
        ticket_type: :annual_plan,
        title: "FY#{Date.current.year} Annual Plan",
        scope_level: :company,
        source_meeting_type: :annual,
        source_meeting: meeting,
        linked_kpis: metrics,
        linked_artifacts: annual_artifacts,
        priority: :medium,
        status: :approved,
        assignee: DEFAULT_ASSIGNEE,
        due_date: Ledgers::TimeAxis.due_date_for(:annual),
        due_cycle: :annual,
        resolved_at: Time.current
      )

      meeting.update!(
        decisions: [ { summary_ticket_id: ticket.id, metrics: } ],
        tickets_to_create: [ { ticket_id: ticket.id, title: ticket.title, status: ticket.status } ],
        status: :closed
      )

      # Phase 31c: 年次計画のサマリーを成果物台帳に自動記録する
      Ledgers::RunnerArtifactPublisher.publish_for!(
        meeting: meeting,
        runner: :annual_plan,
        source_ticket: ticket,
        extra_content: { summary_ticket_id: ticket.id, metrics: metrics }
      )

      meeting
    end

    private

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "annual_plan", scope_level: :company)
    end

    def summary_metrics
      tickets_total = recent_tickets.count
      tickets_overdue = recent_tickets.status_overdue.count
      {
        total_meetings: recent_meetings.count,
        quarterly_reviews: quarterly_review_summaries.count,
        tickets_total:,
        tickets_approved: recent_tickets.status_approved.count,
        overdue_rate: format("%.1f%%", tickets_total.zero? ? 0 : (tickets_overdue.to_f / tickets_total * 100))
      }
    end

    def annual_artifacts
      {
        meetings_by_key: recent_meetings.group(:meeting_key).count,
        tickets_by_status: recent_tickets.group(:status).count.transform_keys do |status|
          status.is_a?(Integer) ? TicketLedger.statuses.key(status) : status.to_s
        end,
        quarterly_review_summaries: quarterly_review_summaries.order(created_at: :desc).map do |ticket|
          { id: ticket.id, title: ticket.title, created_at: ticket.created_at.iso8601 }
        end
      }
    end

    def quarterly_review_summaries
      @quarterly_review_summaries ||= recent_tickets.where(ticket_type: TicketLedger.ticket_types[:quarterly_review])
    end

    def recent_meetings
      @recent_meetings ||= MeetingLedger.where(created_at: range_start..Time.current).where.not(id: @current_meeting_id)
    end

    def recent_tickets
      @recent_tickets ||= TicketLedger.where(created_at: range_start..Time.current)
    end

    def range_start
      @range_start ||= Ledgers::TimeAxis.interval_for(:annual).ago
    end
  end
end
