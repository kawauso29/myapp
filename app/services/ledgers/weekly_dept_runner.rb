module Ledgers
  class WeeklyDeptRunner
    def self.call(service_id:, ticket_inputs: nil)
      new(service_id:, ticket_inputs:).call
    end

    def initialize(service_id:, ticket_inputs: nil)
      @service_id = service_id
      @ticket_inputs = ticket_inputs.presence || default_ticket_inputs
    end

    def call
      definition = meeting_definition!
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        service_id:,
        chair: definition.chair_role,
        participants: definition.participant_roles,
        held_at: Time.current,
        status: :open
      )

      created = []
      hold_items = []
      escalations = []
      decisions = []

      ticket_inputs.each do |input|
        attrs = input.symbolize_keys
        linked_kpis = Array(attrs[:linked_kpis]).compact
        if linked_kpis.blank?
          hold_items << hold_payload(attrs)
          decisions << { title: attrs[:title], result: "held_for_missing_kpis" }
          next
        end

        missing_kpi_keys = missing_kpi_keys(linked_kpis)
        if missing_kpi_keys.present?
          hold_items << hold_payload(attrs, reason: "missing_kpi_definition", missing_kpi_keys:)
          decisions << { title: attrs[:title], result: "held_for_missing_kpi_definition" }
          next
        end

        ticket = create_ticket!(meeting:, attrs:)
        created << { ticket_id: ticket.id, title: ticket.title, status: ticket.status }
        decisions << { ticket_id: ticket.id, result: ticket.status }

        next unless ticket.status_waiting_review?

        escalations << {
          ticket_id: ticket.id,
          escalation_to: ticket.escalation_to,
          reason: "weekly_audit_block"
        }
      end

      meeting.update!(
        decisions:,
        hold_items:,
        tickets_to_create: created,
        escalations:,
        status: :closed
      )
      meeting
    end

    private

    attr_reader :service_id, :ticket_inputs

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "weekly_dept", scope_level: :service)
    end

    def default_ticket_inputs
      [
        {
          ticket_type: "operations",
          title: "weekly_dept default ticket for #{service_id}",
          linked_kpis: [ "kpi:service_health" ],
          audit_ok: true,
          owner_dept: "planning",
          owner_agent: "weekly_dept_runner"
        }
      ]
    end

    def create_ticket!(meeting:, attrs:)
      audit_ok = attrs.fetch(:audit_ok, true)
      TicketLedger.create!(
        ticket_type: attrs.fetch(:ticket_type, "operations"),
        title: attrs.fetch(:title),
        scope_level: :service,
        service_id:,
        business_owner: attrs[:business_owner],
        source_meeting_type: :weekly,
        source_meeting: meeting,
        owner_dept: attrs[:owner_dept],
        owner_agent: attrs[:owner_agent],
        linked_kpis: attrs[:linked_kpis],
        linked_artifacts: attrs[:linked_artifacts] || [],
        priority: attrs[:priority] || :medium,
        status: audit_ok ? :approved : :waiting_review,
        assignee: service_id,
        due_date: Date.current + 7.days,
        due_cycle: :weekly,
        escalation_to: audit_ok ? nil : :monthly
      )
    end

    def hold_payload(attrs, reason: "missing_linked_kpis", missing_kpi_keys: nil)
      {
        title: attrs[:title],
        reason:,
        missing_kpi_keys:,
        next_cycle: "weekly"
      }.compact
    end

    def missing_kpi_keys(linked_kpis)
      linked_kpis - existing_kpi_keys
    end

    def existing_kpi_keys
      @existing_kpi_keys ||= begin
        requested_kpi_keys = ticket_inputs.flat_map { |input| Array(input.symbolize_keys[:linked_kpis]).compact }.uniq
        if requested_kpi_keys.blank?
          []
        else
          KpiLedger.where(kpi_key: requested_kpi_keys).pluck(:kpi_key)
        end
      end
    end
  end
end
