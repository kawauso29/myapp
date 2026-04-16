module Ledgers
  class MonthlyOpsRunner
    ALLOWED_RESOLUTIONS = %w[approved draft cancelled].freeze
    DEFAULT_ASSIGNEE = "monthly_ops_runner".freeze

    def self.call(resolution_map: {})
      new(resolution_map:).call
    end

    def initialize(resolution_map:)
      @resolution_map = (resolution_map || {}).transform_keys(&:to_i)
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

      decisions = []
      target_tickets.find_each do |ticket|
        resolution = normalize_resolution(@resolution_map[ticket.id] || "approved")
        ticket.update!(
          status: resolution,
          assignee: ticket.assignee.presence || DEFAULT_ASSIGNEE,
          due_date: ticket.due_date || (Date.current + 30.days),
          due_cycle: resolution == "draft" ? :weekly : ticket.due_cycle,
          escalation_to: nil
        )
        decisions << { ticket_id: ticket.id, resolution: }
      end

      resolver_result = Ledgers::ImprovementResolver.call
      improvements = {
        detected: 0,
        resolved: resolver_result[:resolved] || resolver_result["resolved"] || 0,
        details: Array(resolver_result[:details] || resolver_result["details"])
      }

      meeting.update!(decisions:, directives: [ { improvements: } ], status: :closed)
      meeting
    end

    private

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "monthly_ops", scope_level: :company)
    end

    def target_tickets
      TicketLedger.status_waiting_review.escalation_to_monthly
    end

    def normalize_resolution(value)
      resolution = value.to_s
      return resolution if ALLOWED_RESOLUTIONS.include?(resolution)

      "approved"
    end
  end
end
