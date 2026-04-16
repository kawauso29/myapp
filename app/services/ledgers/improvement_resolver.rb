module Ledgers
  class ImprovementResolver
    OVERDUE_WINDOW_DAYS = 30
    STALE_SERVICE_DAYS = 14
    OVERDUE_RATE_THRESHOLD = 0.2
    OPEN_STATUSES = %i[waiting_review overdue].freeze

    def self.call
      new.call
    end

    def call
      resolved = []

      open_improvement_tickets.find_each do |ticket|
        next unless resolvable?(ticket)

        ticket.update!(
          status: :approved,
          linked_kpis: updated_linked_kpis(ticket:)
        )
        resolved << {
          ticket_id: ticket.id,
          rule: linked_rule(ticket),
          title: ticket.title
        }
      end

      {
        resolved: resolved.count,
        details: resolved
      }
    end

    private

    def open_improvement_tickets
      TicketLedger.ticket_type_improvement.where(status: OPEN_STATUSES)
    end

    def resolvable?(ticket)
      rule = linked_rule(ticket)
      return false if rule.blank?

      case rule
      when "high_overdue_rate"
        current_overdue_rate <= OVERDUE_RATE_THRESHOLD
      when "missing_kpi_definition"
        missing_kpi_keys_for(ticket).blank?
      when "stale_service"
        stale_service_cleared?(ticket)
      when "monthly_hold_accumulation"
        monthly_hold_count < 3
      else
        false
      end
    end

    def updated_linked_kpis(ticket:)
      linked = normalize_hash(ticket.linked_kpis)
      linked.merge(
        "resolved_at" => Time.current.iso8601,
        "resolution" => resolution_payload(ticket)
      )
    end

    def resolution_payload(ticket)
      case linked_rule(ticket)
      when "high_overdue_rate"
        { "current_rate" => percent(current_overdue_rate) }
      when "missing_kpi_definition"
        { "missing_keys" => missing_kpi_keys_for(ticket) }
      when "stale_service"
        { "last_audit_at" => last_audit_at(service_id: linked_service_id(ticket))&.iso8601 }
      when "monthly_hold_accumulation"
        { "hold_count" => monthly_hold_count }
      else
        {}
      end
    end

    def linked_rule(ticket)
      normalize_hash(ticket.linked_kpis)["rule"]
    end

    def linked_service_id(ticket)
      normalize_hash(ticket.linked_kpis)["service_id"]
    end

    def missing_kpi_keys_for(ticket)
      keys = Array(normalize_hash(ticket.linked_kpis)["keys"]).compact.uniq
      return [] if keys.blank?

      existing = KpiLedger.where(kpi_key: keys).pluck(:kpi_key)
      keys - existing
    end

    def stale_service_cleared?(ticket)
      service_id = linked_service_id(ticket)
      return false if service_id.blank?

      weekly_audit_exists_recently?(service_id:)
    end

    def weekly_audit_exists_recently?(service_id:)
      MeetingLedger.where(meeting_key: "weekly_dept", service_id:)
        .where(held_at: STALE_SERVICE_DAYS.days.ago..Time.current)
        .exists?
    end

    def last_audit_at(service_id:)
      MeetingLedger.where(meeting_key: "weekly_dept", service_id:).maximum(:held_at)
    end

    def monthly_hold_count
      meeting = MeetingLedger.where(meeting_key: "monthly_ops").order(held_at: :desc).first
      return 0 unless meeting

      Array(meeting.hold_items).count
    end

    def current_overdue_rate
      tickets = TicketLedger.where(created_at: OVERDUE_WINDOW_DAYS.days.ago..Time.current)
      total_count = tickets.count
      return 0.0 if total_count.zero?

      tickets.status_overdue.count.to_f / total_count
    end

    def percent(rate)
      "#{(rate * 100).round(1)}%"
    end

    def normalize_hash(value)
      case value
      when Hash
        value
      else
        {}
      end
    end
  end
end
