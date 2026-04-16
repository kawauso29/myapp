module Ledgers
  class ImprovementResolver
    OVERDUE_RATE_THRESHOLD = 20.0
    OVERDUE_RATE_WINDOW = 30.days
    MONTHLY_HOLD_THRESHOLD = 3
    STALE_TICKET_WINDOW = 14.days

    def self.call
      new.call
    end

    def call
      resolved_tickets = []

      open_improvement_tickets.find_each do |ticket|
        next unless resolved?(ticket)

        ticket.update!(status: :approved)
        resolved_tickets << ticket
      end

      {
        operation: "resolve_improvements",
        resolved_tickets_count: resolved_tickets.size,
        resolved_tickets: resolved_tickets.map { |ticket| { id: ticket.id, title: ticket.title, rule: rule_for(ticket) } }
      }
    end

    private

    def resolved?(ticket)
      case rule_for(ticket)
      when "overdue_rate"
        current_overdue_rate <= OVERDUE_RATE_THRESHOLD
      when "missing_kpi_definition"
        unresolved_kpi_keys(ticket).blank?
      when "monthly_holds"
        latest_monthly_hold_count <= MONTHLY_HOLD_THRESHOLD
      when "stale_tickets"
        stale_ticket_scope.where.not(id: ticket.id).none?
      else
        false
      end
    end

    def rule_for(ticket)
      ticket.linked_kpis["rule"] || ticket.linked_kpis[:rule]
    end

    def current_overdue_rate
      scope = base_ticket_scope.where(created_at: OVERDUE_RATE_WINDOW.ago..Time.current)
      total = scope.count
      return 0 if total.zero?

      (scope.status_overdue.count.to_f / total * 100).round(1)
    end

    def unresolved_kpi_keys(ticket)
      keys = Array(ticket.linked_kpis["keys"] || ticket.linked_kpis[:keys]).compact
      return [] if keys.blank?

      existing = KpiLedger.where(kpi_key: keys).pluck(:kpi_key)
      keys - existing
    end

    def latest_monthly_hold_count
      latest_monthly_meeting = MeetingLedger.where(meeting_key: "monthly_ops").order(held_at: :desc, id: :desc).first
      return 0 if latest_monthly_meeting.blank?

      Array(latest_monthly_meeting.hold_items).size
    end

    def open_improvement_tickets
      TicketLedger.ticket_type_improvement.status_waiting_review
    end

    def stale_ticket_scope
      base_ticket_scope.status_waiting_review.where("created_at <= ?", STALE_TICKET_WINDOW.ago)
    end

    def base_ticket_scope
      TicketLedger.where.not(ticket_type: TicketLedger.ticket_types[:improvement])
    end
  end
end
