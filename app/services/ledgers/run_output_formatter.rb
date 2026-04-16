module Ledgers
  class RunOutputFormatter
    def self.format(meeting:, operation:)
      new(meeting:, operation:).format
    end

    def initialize(meeting:, operation:)
      @meeting = meeting
      @operation = operation
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
          holds: {
            grouped_by_reason: grouped_hold_reasons,
            missing_kpi_definition_keys: missing_kpi_definition_keys
          }
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
  end
end
