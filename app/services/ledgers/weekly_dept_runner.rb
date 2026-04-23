module Ledgers
  class WeeklyDeptRunner
    def self.call(service_id:, ticket_inputs: nil, present_roles: nil, meeting_key: "weekly_dept", use_daily_anomalies: true)
      new(service_id:, ticket_inputs:, present_roles:, meeting_key:, use_daily_anomalies:).call
    end

    def initialize(service_id:, ticket_inputs: nil, present_roles: nil, meeting_key: "weekly_dept", use_daily_anomalies: true)
      @service_id = service_id
      raw_inputs = ticket_inputs.presence || default_ticket_inputs
      @ticket_inputs = raw_inputs.map(&:symbolize_keys)
      @present_roles = present_roles
      @meeting_key = meeting_key
      @use_daily_anomalies = use_daily_anomalies
    end

    def call
      definition = meeting_definition!
      preflight = Ledgers::PreflightValidator.call(definition:, present_roles: @present_roles)
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        service_id:,
        chair: definition.chair_role,
        participants: preflight.participants,
        role_fill_rate: preflight.role_fill_rate,
        held_at: Time.current,
        status: :open,
        idempotency_key: Ledgers::IdempotencyKey.for_meeting(
          prefix: @meeting_key,
          parts: [ service_id ],
          cadence: :weekly
        )
      )

      created = []
      hold_items = []
      escalations = []
      decisions = []

      entry_check = Stops::EntryGuard.check(scope_level: :service, service_id:)

      all_ticket_inputs = memoized_all_ticket_inputs

      all_ticket_inputs.each do |input|
        attrs = input
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

        if entry_check.blocked?
          hold_items << hold_payload(attrs, reason: "entry_guard_blocked")
          decisions << { title: attrs[:title], result: "held_for_active_stop" }
          next
        end

        begin
          ticket = create_ticket!(meeting:, attrs:)
        rescue ActiveRecord::RecordNotSaved => e
          reason = ticket_blocked_reason(e.record)
          hold_items << hold_payload(attrs, reason:)
          decisions << { title: attrs[:title], result: "held_for_#{reason}" }
          next
        end
        created << { ticket_id: ticket.id, title: ticket.title, status: ticket.status }
        decisions << { ticket_id: ticket.id, result: ticket.status }

        next unless ticket.status_waiting_review?

        escalations << {
          ticket_id: ticket.id,
          escalation_to: ticket.escalation_to,
          reason: "weekly_audit_block"
        }
      end

      detector_result = Ledgers::ImprovementDetector.call
      resolver_result = Ledgers::ImprovementResolver.call
      improvements = {
        detected: detector_result.fetch(:detected, 0),
        resolved: resolver_result.fetch(:resolved, 0),
        details: Array(detector_result.fetch(:details, [])) + Array(resolver_result.fetch(:details, []))
      }

      meeting.update!(
        decisions:,
        hold_items:,
        carry_over_items: hold_items,
        tickets_to_create: created,
        escalations:,
        directives: [ { improvements: } ],
        status: :closed
      )

      # Phase 31c: 会議の議事要約を成果物台帳に自動記録する
      Ledgers::RunnerArtifactPublisher.publish_for!(
        meeting: meeting,
        runner: @meeting_key.to_sym,
        service_id: service_id
      )

      meeting
    end

    private

    attr_reader :service_id, :ticket_inputs

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: @meeting_key, scope_level: :service)
    end

    def default_ticket_inputs
      [
        {
          ticket_type: "operations",
          title: "#{@meeting_key} default ticket for #{service_id}",
          linked_kpis: [ "kpi:service_health" ],
          audit_ok: true,
          owner_dept: "planning",
          owner_agent: "#{@meeting_key}_runner"
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
        due_date: Ledgers::TimeAxis.due_date_for(:weekly),
        due_cycle: :weekly,
        escalation_to: audit_ok ? nil : :monthly,
        # Phase 44e: Runner が生成する運用チケットは template 不要（Copilot 入力ではない）
        skip_template_guard: true
      )
    end

    def ticket_blocked_reason(record)
      return "callback_blocked" unless record.is_a?(TicketLedger)

      base_msgs = record.errors.full_messages
      if base_msgs.any? { |m| m.include?("lane capacity exceeded") }
        "lane_capacity_exceeded"
      else
        "callback_blocked"
      end
    end

    def hold_payload(attrs, reason: "missing_linked_kpis", missing_kpi_keys: nil)
      {
        title: attrs[:title],
        reason:,
        missing_kpi_keys:,
        next_cycle: "weekly"
      }.compact
    end

    def memoized_all_ticket_inputs
      @memoized_all_ticket_inputs ||= ticket_inputs + daily_anomaly_inputs
    end

    def missing_kpi_keys(linked_kpis)
      linked_kpis - existing_kpi_keys
    end

    def existing_kpi_keys
      @existing_kpi_keys ||= begin
        requested_kpi_keys = memoized_all_ticket_inputs.flat_map { |input| Array(input[:linked_kpis]).compact }.uniq
        if requested_kpi_keys.blank?
          []
        else
          KpiLedger.where(kpi_key: requested_kpi_keys).pluck(:kpi_key)
        end
      end
    end

    def daily_anomaly_inputs
      return [] unless @use_daily_anomalies

      @daily_anomaly_inputs ||= fetch_daily_anomaly_inputs
    end

    def fetch_daily_anomaly_inputs
      latest_daily = MeetingLedger
                       .where(meeting_type: :daily, service_id: @service_id)
                       .order(held_at: :desc)
                       .first
      return [] unless latest_daily

      existing_titles = ticket_inputs.map { |i| i[:title].to_s }

      Array(latest_daily.hold_items)
        .select { |item| (item["type"] || item[:type]).to_s == "anomaly" }
        .filter_map do |item|
          kpi_key = (item["kpi_key"] || item[:kpi_key]).to_s
          next if kpi_key.blank?

          anomaly_title = "Anomaly: #{kpi_key}"
          next if existing_titles.include?(anomaly_title)

          {
            ticket_type: "operations",
            title: anomaly_title,
            linked_kpis: [ kpi_key ],
            audit_ok: false,
            owner_dept: "system",
            owner_agent: "daily_runner"
          }
        end
    end
  end
end
