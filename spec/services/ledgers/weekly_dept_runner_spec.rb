require "rails_helper"

RSpec.describe Ledgers::WeeklyDeptRunner do
  describe ".call" do
    let!(:weekly_definition) do
      create(:meeting_definition,
             meeting_key: "weekly_dept",
             meeting_type: :weekly,
             scope_level: :service,
             service_id: "ai_sns")
    end

    before do
      allow(Ledgers::ImprovementDetector).to receive(:call).and_return({ detected: 0, details: [] })
      allow(Ledgers::ImprovementResolver).to receive(:call).and_return({ resolved: 0, details: [] })
    end

    it "sets waiting_review + escalation_to monthly when weekly audit is NG" do
      create(:kpi_ledger, kpi_key: "kpi:risk", scope_level: :service, service_id: "ai_sns")

      meeting = described_class.call(
        service_id: "ai_sns",
        ticket_inputs: [
          {
            ticket_type: "audit",
            title: "needs review",
            linked_kpis: [ "kpi:risk" ],
            audit_ok: false
          }
        ]
      )

      ticket = TicketLedger.last
      expect(ticket).to be_status_waiting_review
      expect(ticket).to be_escalation_to_monthly
      expect(ticket.linked_kpis).to eq([ "kpi:risk" ])
      expect(ticket.assignee).to eq("ai_sns")
      expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:weekly))
      expect(ticket.resolved_at).to be_nil
      expect(ticket.source_meeting).to eq(meeting)
      expect(meeting.escalations.size).to eq(1)
    end

    it "auto-resolves approved ticket with resolved_at when weekly audit is OK" do
      create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

      described_class.call(
        service_id: "ai_sns",
        use_daily_anomalies: false,
        ticket_inputs: [
          {
            ticket_type: "ops",
            title: "approved by weekly audit",
            linked_kpis: [ "kpi:service_health" ],
            audit_ok: true
          }
        ]
      )

      ticket = TicketLedger.find_by!(title: "approved by weekly audit")
      expect(ticket).to be_status_approved
      expect(ticket.resolved_at).to be_present
      expect(ticket.assignee).to eq("ai_sns")
      expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:weekly))
    end

    it "holds ticket creation when linked_kpis is empty" do
      expect do
        described_class.call(
          service_id: "ai_sns",
          ticket_inputs: [
            {
              ticket_type: "ops",
              title: "missing kpi",
              linked_kpis: []
            }
          ]
        )
      end.not_to change(TicketLedger, :count)

      meeting = MeetingLedger.last
      expect(meeting.hold_items).to include(a_hash_including("reason" => "missing_linked_kpis"))
    end

    it "holds ticket creation when linked_kpis include unknown keys" do
      create(:kpi_ledger, kpi_key: "kpi:known", scope_level: :service, service_id: "ai_sns")

      expect do
        described_class.call(
          service_id: "ai_sns",
          ticket_inputs: [
            {
              ticket_type: "ops",
              title: "unknown kpi",
              linked_kpis: [ "kpi:known", "kpi:unknown" ]
            }
          ]
        )
      end.not_to change(TicketLedger, :count)

      meeting = MeetingLedger.last
      expect(meeting.hold_items).to include(
        a_hash_including("reason" => "missing_kpi_definition", "missing_kpi_keys" => [ "kpi:unknown" ])
      )
    end

    it "calls improvement detector and resolver after weekly flow" do
      create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

      described_class.call(
        service_id: "ai_sns",
        ticket_inputs: [
          {
            ticket_type: "ops",
            title: "weekly ticket",
            linked_kpis: [ "kpi:service_health" ],
            audit_ok: true
          }
        ]
      )

      expect(Ledgers::ImprovementDetector).to have_received(:call)
      expect(Ledgers::ImprovementResolver).to have_received(:call)
    end

    it "sets a deterministic idempotency_key and role_fill_rate from PreflightValidator" do
      create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

      meeting = described_class.call(
        service_id: "ai_sns",
        ticket_inputs: [
          { ticket_type: "ops", title: "weekly", linked_kpis: [ "kpi:service_health" ], audit_ok: true }
        ],
        present_roles: %w[planning dev audit]
      )

      expected_key = "weekly_dept:ai_sns:#{Ledgers::TimeAxis.slot_token(:weekly)}"
      expect(meeting.idempotency_key).to eq(expected_key)
      # definition has 5 participant_roles, so 3 / 5 = 0.6
      expect(meeting.role_fill_rate.to_f).to be_within(0.0001).of(0.6)
      expect(meeting.participants).to match_array(%w[planning dev audit])
    end

    it "copies hold_items into carry_over_items for the next weekly cycle" do
      described_class.call(
        service_id: "ai_sns",
        ticket_inputs: [
          { ticket_type: "ops", title: "missing kpi", linked_kpis: [] }
        ]
      )

      meeting = MeetingLedger.last
      expect(meeting.hold_items).to be_present
      expect(meeting.carry_over_items).to eq(meeting.hold_items)
    end

    it "holds ticket creation when entry guard is blocked by an active stop" do
      create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

      blocked_result = instance_double(Stops::EntryGuard::Result, allowed?: false, blocked?: true)
      allow(Stops::EntryGuard).to receive(:check).and_return(blocked_result)

      expect do
        described_class.call(
          service_id: "ai_sns",
          ticket_inputs: [
            {
              ticket_type: "ops",
              title: "blocked by stop",
              linked_kpis: [ "kpi:service_health" ],
              audit_ok: true
            }
          ]
        )
      end.not_to change(TicketLedger, :count)

      meeting = MeetingLedger.last
      expect(meeting.hold_items).to include(a_hash_including("reason" => "entry_guard_blocked"))
      expect(meeting.decisions).to include(a_hash_including("result" => "held_for_active_stop"))
    end

    context "when lane capacity is exceeded during ticket creation" do
      around do |example|
        TicketLedger.enforce_lane_capacity = true
        example.run
      ensure
        TicketLedger.enforce_lane_capacity = false
      end

      before do
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")
      end

      it "holds the ticket instead of raising an error when RecordNotSaved has lane_capacity_exceeded" do
        blocked_ticket = TicketLedger.new
        blocked_ticket.errors.add(:base, "lane capacity exceeded for weekly_improvement (scope=service, service=ai_sns)")
        not_saved_error = ActiveRecord::RecordNotSaved.new("Failed to save the record", blocked_ticket)
        allow(TicketLedger).to receive(:create!).and_raise(not_saved_error)

        expect do
          described_class.call(
            service_id: "ai_sns",
            use_daily_anomalies: false,
            ticket_inputs: [
              {
                ticket_type: "operations",
                title: "over capacity ticket",
                linked_kpis: [ "kpi:service_health" ],
                audit_ok: true
              }
            ]
          )
        end.not_to raise_error

        meeting = MeetingLedger.last
        expect(meeting.hold_items).to include(a_hash_including("reason" => "lane_capacity_exceeded"))
        expect(meeting.decisions).to include(a_hash_including("result" => "held_for_lane_capacity_exceeded"))
      end

      it "holds the ticket with callback_blocked reason when RecordNotSaved has unknown cause" do
        blocked_ticket = TicketLedger.new
        blocked_ticket.errors.add(:base, "ticket creation is blocked by active stops: #1:manual/service(ai_sns)")
        not_saved_error = ActiveRecord::RecordNotSaved.new("Failed to save the record", blocked_ticket)
        allow(TicketLedger).to receive(:create!).and_raise(not_saved_error)

        expect do
          described_class.call(
            service_id: "ai_sns",
            use_daily_anomalies: false,
            ticket_inputs: [
              {
                ticket_type: "operations",
                title: "blocked ticket",
                linked_kpis: [ "kpi:service_health" ],
                audit_ok: true
              }
            ]
          )
        end.not_to raise_error

        meeting = MeetingLedger.last
        expect(meeting.hold_items).to include(a_hash_including("reason" => "callback_blocked"))
      end
    end

    context "when meeting_key is ui_check" do
      let!(:ui_check_definition) do
        create(:meeting_definition,
               meeting_key: "ui_check",
               meeting_type: :weekly,
               scope_level: :service,
               service_id: "ai_sns")
      end

      it "creates MeetingLedger with meeting_key: ui_check and correct idempotency_key" do
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

        meeting = described_class.call(
          service_id: "ai_sns",
          meeting_key: "ui_check",
          ticket_inputs: [
            { ticket_type: "ops", title: "ui check ticket", linked_kpis: [ "kpi:service_health" ], audit_ok: true }
          ]
        )

        expect(meeting.meeting_key).to eq("ui_check")
        expect(meeting.idempotency_key).to eq("ui_check:ai_sns:#{Ledgers::TimeAxis.slot_token(:weekly)}")
      end
    end

    context "when daily anomaly hold_items exist" do
      let!(:daily_definition) do
        MeetingDefinition.find_or_create_by!(meeting_key: "daily") do |d|
          d.meeting_type = :daily
          d.scope_level = :service
          d.service_id = "ai_sns"
          d.chair_role = "system"
          d.participant_roles = []
        end
      end

      let!(:kpi_anomaly) { create(:kpi_ledger, kpi_key: "kpi:anomaly_target", scope_level: :service, service_id: "ai_sns") }

      let!(:daily_meeting) do
        create(:meeting_ledger,
               meeting_definition: daily_definition,
               meeting_key: "daily",
               meeting_type: :daily,
               service_id: "ai_sns",
               held_at: 1.hour.ago,
               hold_items: [
                 { "type" => "anomaly", "kpi_key" => "kpi:anomaly_target", "grade" => "critical" }
               ])
      end

      it "converts daily anomalies into ticket_inputs automatically" do
        meeting = described_class.call(
          service_id: "ai_sns",
          ticket_inputs: []
        )

        anomaly_ticket = TicketLedger.find_by(title: "Anomaly: kpi:anomaly_target")
        expect(anomaly_ticket).to be_present
        expect(anomaly_ticket).to be_status_waiting_review
        expect(anomaly_ticket.linked_kpis).to include("kpi:anomaly_target")
        expect(meeting.tickets_to_create).to include(a_hash_including("ticket_id" => anomaly_ticket.id))
      end

      it "does not double-add anomaly if already in explicit ticket_inputs" do
        expect do
          described_class.call(
            service_id: "ai_sns",
            ticket_inputs: [
              {
                ticket_type: "operations",
                title: "Anomaly: kpi:anomaly_target",
                linked_kpis: [ "kpi:anomaly_target" ],
                audit_ok: false
              }
            ]
          )
        end.to change(TicketLedger, :count).by(1)

        anomaly_tickets = TicketLedger.where(title: "Anomaly: kpi:anomaly_target")
        expect(anomaly_tickets.count).to eq(1)
      end

      it "skips anomaly conversion when use_daily_anomalies: false" do
        expect do
          described_class.call(
            service_id: "ai_sns",
            ticket_inputs: [],
            use_daily_anomalies: false
          )
        end.not_to change(TicketLedger, :count)
      end
    end

    context "default ticket behavior (ticket_inputs not provided)" do
      before do
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")
      end

      it "creates a default operations ticket with the expected title when ticket_inputs is omitted" do
        expect do
          described_class.call(service_id: "ai_sns", use_daily_anomalies: false)
        end.to change(TicketLedger, :count).by(1)

        ticket = TicketLedger.find_by(title: "weekly_dept default ticket for ai_sns")
        expect(ticket).to be_present
        expect(ticket.ticket_type).to eq("operations")
        expect(ticket.linked_kpis).to eq(["kpi:service_health"])
        expect(ticket.due_cycle).to eq("weekly")
        expect(ticket.assignee).to eq("ai_sns")
        expect(ticket).to be_status_approved
        expect(ticket.resolved_at).to be_present
        expect(ticket.scope_level).to eq("service")
        expect(ticket.service_id).to eq("ai_sns")
        expect(ticket.due_date).to eq(Ledgers::TimeAxis.due_date_for(:weekly))
      end

      it "skips default ticket creation when an active default ticket already exists" do
        create(:ticket_ledger,
               title: "weekly_dept default ticket for ai_sns",
               ticket_type: :operations,
               service_id: "ai_sns",
               due_cycle: :weekly,
               status: :approved)

        expect do
          described_class.call(service_id: "ai_sns", use_daily_anomalies: false)
        end.not_to change(TicketLedger, :count)

        meeting = MeetingLedger.last
        expect(meeting.decisions).to include(
          a_hash_including("result" => "skipped_duplicate_default")
        )
      end

      it "creates a new default ticket when the previous one is completed" do
        create(:ticket_ledger,
               title: "weekly_dept default ticket for ai_sns",
               ticket_type: :operations,
               service_id: "ai_sns",
               due_cycle: :weekly,
               status: :completed)

        expect do
          described_class.call(service_id: "ai_sns", use_daily_anomalies: false)
        end.to change(TicketLedger, :count).by(1)

        ticket = TicketLedger.ticket_type_operations
                             .where(title: "weekly_dept default ticket for ai_sns", service_id: "ai_sns")
                             .where(status: TicketLedger.statuses[:approved])
                             .first
        expect(ticket).to be_present
      end
    end

    context "AI SNS 計画チケット（approved → planned）" do
      let!(:approved_ticket) do
        create(:ticket_ledger,
               status: :approved,
               idempotency_key: "ai_sns_plan:test-item-002",
               due_cycle: :monthly)
      end

      it "ai_sns_plan の approved チケットを planned に昇格させる" do
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

        described_class.call(service_id: "ai_sns")

        expect(approved_ticket.reload).to be_status_planned
      end

      it "昇格した ai_sns_plan チケットを meeting decisions に記録する" do
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

        meeting = described_class.call(service_id: "ai_sns")

        expect(meeting.decisions).to include(
          a_hash_including("ticket_id" => approved_ticket.id, "result" => "planned")
        )
      end

      it "approved でない ai_sns_plan チケットには影響しない" do
        draft_ticket = create(:ticket_ledger,
                              status: :draft,
                              idempotency_key: "ai_sns_plan:test-item-003",
                              due_cycle: :monthly)
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")

        described_class.call(service_id: "ai_sns")

        expect(draft_ticket.reload).to be_status_draft
        expect(approved_ticket.reload).to be_status_planned
      end
    end

    context "Phase 45b: customer_notice draft generation" do
      it "creates a customer_notice draft on every weekly meeting regardless of feedback" do
        expect do
          described_class.call(service_id: "ai_sns", ticket_inputs: [])
        end.to change { ArtifactLedger.artifact_type_customer_notice.count }.by(1)

        notice = ArtifactLedger.artifact_type_customer_notice.last
        expect(notice.status).to eq("draft")
        expect(notice.scope_level).to eq("service")
        expect(notice.service_id).to eq("ai_sns")
        expect(notice.content).to include("meeting_id", "held_at", "approved_tickets", "note")
      end

      it "does not create a duplicate customer_notice when one with the same title already exists" do
        week_label = Date.current.beginning_of_week(:monday).iso8601
        create(:artifact_ledger,
               artifact_type: :customer_notice,
               scope_level: :service,
               service_id: "ai_sns",
               title: "Customer Notice Draft (ai_sns) #{week_label}",
               status: :draft)

        expect do
          described_class.call(service_id: "ai_sns", ticket_inputs: [])
        end.not_to change { ArtifactLedger.artifact_type_customer_notice.count }
      end

      it "lists approved tickets in the customer_notice content" do
        create(:kpi_ledger, kpi_key: "kpi:service_health", scope_level: :service, service_id: "ai_sns")
        described_class.call(
          service_id: "ai_sns",
          ticket_inputs: [
            {
              ticket_type: "operations",
              title: "Ship feature X",
              linked_kpis: [ "kpi:service_health" ],
              audit_ok: true,
              owner_dept: "dev",
              owner_agent: "weekly_dept_runner"
            }
          ]
        )

        notice = ArtifactLedger.artifact_type_customer_notice.last
        approved = notice.content["approved_tickets"]
        expect(approved).to be_an(Array)
        expect(approved.map { |t| t["title"] }).to include("Ship feature X")
      end
    end
  end
end
