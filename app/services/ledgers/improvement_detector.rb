module Ledgers
  class ImprovementDetector
    OVERDUE_RATE_THRESHOLD = 20.0
    OVERDUE_RATE_WINDOW = 30.days
    KPI_MISSING_WINDOW = 7.days
    MONTHLY_HOLD_THRESHOLD = 3
    STALE_TICKET_WINDOW = 14.days
    DEFAULT_ASSIGNEE = "improvement_detector".freeze

    def self.call
      new.call
    end

    def call
      created_tickets = []

      [ overdue_rate_detection, missing_kpi_detection, monthly_holds_detection, stale_tickets_detection ].compact.each do |detection|
        ticket = create_ticket!(detection)
        created_tickets << ticket if ticket
      end

      {
        operation: "detect_improvements",
        created_tickets_count: created_tickets.size,
        created_tickets: created_tickets.map { |ticket| { id: ticket.id, title: ticket.title, rule: ticket.linked_kpis["rule"] } }
      }
    end

    private

    def create_ticket!(detection)
      return if duplicate_open_ticket?(detection[:rule], detection[:title_prefix])

      TicketLedger.create!(
        ticket_type: :improvement,
        title: detection[:title],
        scope_level: :company,
        source_meeting_type: :weekly,
        linked_kpis: detection[:linked_kpis],
        linked_artifacts: [],
        priority: :medium,
        status: :waiting_review,
        assignee: DEFAULT_ASSIGNEE,
        due_date: Date.current + 14.days,
        due_cycle: :weekly
      )
    end

    def overdue_rate_detection
      scope = base_ticket_scope.where(created_at: OVERDUE_RATE_WINDOW.ago..Time.current)
      total = scope.count
      return if total.zero?

      overdue_rate = (scope.status_overdue.count.to_f / total * 100).round(1)
      return if overdue_rate <= OVERDUE_RATE_THRESHOLD

      {
        rule: "overdue_rate",
        title_prefix: "High overdue rate detected",
        title: "High overdue rate detected (#{overdue_rate}%)",
        linked_kpis: {
          rule: "overdue_rate",
          value: "#{overdue_rate}%",
          threshold: "#{OVERDUE_RATE_THRESHOLD.to_i}%"
        }
      }
    end

    def missing_kpi_detection
      recent_weekly = MeetingLedger.where(meeting_key: "weekly_dept", created_at: KPI_MISSING_WINDOW.ago..Time.current)
      missing_keys = recent_weekly.flat_map do |meeting|
        Array(meeting.hold_items).filter_map do |item|
          payload = item.with_indifferent_access
          next unless payload[:reason] == "missing_kpi_definition"

          Array(payload[:missing_kpi_keys])
        end
      end.flatten.uniq.sort
      return if missing_keys.blank?

      {
        rule: "missing_kpi_definition",
        title_prefix: "KPI definitions missing for:",
        title: "KPI definitions missing for: #{missing_keys.join(', ')}",
        linked_kpis: {
          rule: "missing_kpi_definition",
          keys: missing_keys
        }
      }
    end

    def monthly_holds_detection
      latest_monthly_meeting = MeetingLedger.where(meeting_key: "monthly_ops").order(held_at: :desc, id: :desc).first
      return if latest_monthly_meeting.blank?

      hold_count = Array(latest_monthly_meeting.hold_items).size
      return if hold_count <= MONTHLY_HOLD_THRESHOLD

      {
        rule: "monthly_holds",
        title_prefix: "Monthly ops has",
        title: "Monthly ops has #{hold_count} unresolved holds",
        linked_kpis: {
          rule: "monthly_holds",
          value: hold_count,
          threshold: MONTHLY_HOLD_THRESHOLD
        }
      }
    end

    def stale_tickets_detection
      stale_count = stale_ticket_scope.count
      return if stale_count.zero?

      {
        rule: "stale_tickets",
        title_prefix: "stale for 14+ days",
        title: "#{stale_count} tickets stale for 14+ days",
        linked_kpis: {
          rule: "stale_tickets",
          value: stale_count,
          threshold: "0"
        }
      }
    end

    def duplicate_open_ticket?(rule, title_prefix)
      open_improvement_tickets
        .where("linked_kpis ->> 'rule' = ? OR title LIKE ?", rule, "#{title_prefix}%")
        .exists?
    end

    def open_improvement_tickets
      TicketLedger.ticket_type_improvement.where.not(status: [ :approved, :cancelled ])
    end

    def stale_ticket_scope
      base_ticket_scope.status_waiting_review.where("created_at <= ?", STALE_TICKET_WINDOW.ago)
    end

    def base_ticket_scope
      TicketLedger.where.not(ticket_type: TicketLedger.ticket_types[:improvement])
    end
  end
end
