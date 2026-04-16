module Ledgers
  class QuarterlyReviewRunner
    DEFAULT_ASSIGNEE = "quarterly_review_runner".freeze

    def self.call
      new.call
    end

    def call
      definition = meeting_definition!
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        chair: definition.chair_role,
        participants: definition.participant_roles,
        held_at: Time.current,
        status: :open
      )

      metrics = summary_metrics
      snapshot_list = kpi_snapshots.order(recorded_on: :desc).map do |snapshot|
        { id: snapshot.id, period: snapshot.period, recorded_on: snapshot.recorded_on.iso8601 }
      end
      ticket = TicketLedger.create!(
        ticket_type: :quarterly_review,
        title: "Q#{quarter_number} #{Date.current.year} Review Summary",
        scope_level: :company,
        source_meeting_type: :quarterly,
        source_meeting: meeting,
        linked_kpis: metrics,
        linked_artifacts: snapshot_list,
        priority: :medium,
        status: :approved,
        assignee: DEFAULT_ASSIGNEE,
        due_date: Date.current + 90.days,
        due_cycle: :quarterly,
        resolved_at: Time.current
      )

      meeting.update!(
        decisions: [ { summary_ticket_id: ticket.id, metrics: } ],
        tickets_to_create: [ { ticket_id: ticket.id, title: ticket.title, status: ticket.status } ],
        status: :closed
      )
      Ledgers::ImprovementEscalator.call
      meeting
    end

    private

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "quarterly_review", scope_level: :company)
    end

    def summary_metrics
      {
        meetings_held: recent_meetings.count,
        tickets_total: recent_tickets.count,
        tickets_approved: recent_tickets.status_approved.count,
        tickets_cancelled: recent_tickets.status_cancelled.count,
        tickets_overdue: recent_tickets.status_overdue.count
      }
    end

    def quarter_number
      ((Date.current.month - 1) / 3) + 1
    end

    def recent_meetings
      @recent_meetings ||= MeetingLedger.where(created_at: range_start..Time.current, meeting_key: %w[weekly_dept monthly_ops])
    end

    def recent_tickets
      @recent_tickets ||= TicketLedger.where(created_at: range_start..Time.current)
    end

    def kpi_snapshots
      @kpi_snapshots ||= KpiSnapshot.where(recorded_on: range_start.to_date..Date.current)
    end

    def range_start
      @range_start ||= 90.days.ago
    end
  end
end
