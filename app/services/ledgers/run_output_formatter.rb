module Ledgers
  class RunOutputFormatter
    def self.format(meeting:, operation:, improvements: nil)
      new(meeting:, operation:, improvements:).format
    end

    def initialize(meeting:, operation:, improvements: nil)
      @meeting = meeting
      @operation = operation
      @improvements = improvements
    end

    def format
      JSON.pretty_generate(
        {
          operation: @operation,
          meeting_ledger: {
            id: @meeting.id,
            meeting_key: @meeting.meeting_key,
            service_id: @meeting.service_id,
            created_at: @meeting.created_at&.iso8601
          },
          counts: {
            tickets_created: tickets_created_count,
            held_items: hold_items.count
          },
          tickets: {
            info: tickets_info
          },
          holds: {
            grouped_by_reason: grouped_hold_reasons,
            missing_kpi_definition_keys: missing_kpi_definition_keys
          },
          improvements: improvements_payload
        }
      )
    end

    private

    def hold_items
      Array(@meeting.hold_items)
    end

    def tickets_created_count
      Array(@meeting.tickets_to_create).count
    end

    def tickets_info
      return [] if created_ticket_ids.blank?

      TicketLedger.where(id: created_ticket_ids).order(:id).map do |ticket|
        {
          ticket_id: ticket.id,
          title: ticket.title,
          status: ticket.status,
          assignee: ticket.assignee,
          due_date: ticket.due_date&.iso8601
        }
      end
    end

    def created_ticket_ids
      @created_ticket_ids ||= Array(@meeting.tickets_to_create)
        .filter_map { |ticket| ticket["ticket_id"] || ticket[:ticket_id] }
    end

    def grouped_hold_reasons
      hold_items
        .group_by { |item| item["reason"] || item[:reason] || "unknown" }
        .sort_by { |reason, _items| reason }
        .to_h { |reason, items| [ reason, items.count ] }
    end

    def missing_kpi_definition_keys
      hold_items
        .filter_map { |item| item["missing_kpi_keys"] || item[:missing_kpi_keys] }
        .flatten
        .compact
        .uniq
        .sort
    end

    def improvements_payload
      payload = @improvements.presence || improvement_directive
      return default_improvements_payload if payload.blank?

      {
        detected: fetch_from_hash(payload, :detected, default: 0),
        resolved: fetch_from_hash(payload, :resolved, default: 0),
        details: Array(fetch_from_hash(payload, :details, default: []))
      }
    end

    def improvement_directive
      return {} unless @meeting.respond_to?(:directives)

      Array(@meeting.directives)
        .map { |directive| fetch_from_hash(directive, :improvements, default: {}) }
        .find(&:present?)
    end

    def default_improvements_payload
      {
        detected: 0,
        resolved: 0,
        details: []
      }
    end

    def fetch_from_hash(hash, key, default:)
      return default unless hash.respond_to?(:[])

      hash[key] || hash[key.to_s] || default
    end
  end
end
