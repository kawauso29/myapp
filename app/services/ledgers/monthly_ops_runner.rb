module Ledgers
  class MonthlyOpsRunner
    ALLOWED_RESOLUTIONS = %w[approved draft cancelled].freeze
    DEFAULT_ASSIGNEE = "monthly_ops_runner".freeze

    def self.call(resolution_map: {}, present_roles: nil)
      new(resolution_map:, present_roles:).call
    end

    def initialize(resolution_map:, present_roles: nil)
      @resolution_map = (resolution_map || {}).transform_keys(&:to_i)
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
        idempotency_key: Ledgers::IdempotencyKey.for_meeting(prefix: "monthly_ops")
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
      escalation_result = Ledgers::ImprovementEscalator.call
      improvements = {
        detected: 0,
        resolved: resolver_result.fetch(:resolved, 0),
        overdue_marked: escalation_result.fetch(:overdue_marked, 0),
        escalated_monthly: escalation_result.fetch(:escalated_monthly, 0),
        escalated_quarterly: escalation_result.fetch(:escalated_quarterly, 0),
        details: Array(resolver_result.fetch(:details, [])) + Array(escalation_result.fetch(:details, []))
      }

      meeting.update!(decisions:, directives: [ { improvements: } ], status: :closed)

      # Phase 31c: 月次会議の議事要約を成果物台帳に自動記録する
      Ledgers::RunnerArtifactPublisher.publish_for!(meeting: meeting, runner: :monthly_ops)

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
