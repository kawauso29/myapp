require "rails_helper"

RSpec.describe Ledgers::ImprovementDetector do
  describe ".call" do
    let!(:weekly_definition) do
      create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
    end
    let!(:monthly_definition) do
      create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil)
    end
    let!(:ui_check_definition) do
      create(:meeting_definition, meeting_key: "ui_check", meeting_type: :weekly, scope_level: :service, service_id: "ai_sns")
    end

    before do
      allow(Ledgers::SlackNotifier).to receive(:notify)
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
    end

    it "triggers high_overdue_rate rule" do
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      create_list(:ticket_ledger, 3, status: :approved, created_at: 2.days.ago)
      create_list(:ticket_ledger, 2, status: :overdue, created_at: 2.days.ago)

      result = described_class.call

      ticket = TicketLedger.ticket_type_improvement.last
      expect(result[:detected]).to eq(1)
      expect(ticket.title).to include("Improvement: High overdue rate")
      expect(ticket.linked_kpis).to include("rule" => "high_overdue_rate")
    end

    it "triggers missing_kpi_definition rule" do
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      create(:meeting_ledger,
             meeting_definition: weekly_definition,
             meeting_key: "weekly_dept",
             hold_items: [ { reason: "missing_kpi_definition", missing_kpi_keys: [ "kpi:a", "kpi:b", "kpi:a" ] } ],
             status: :closed)

      result = described_class.call

      ticket = TicketLedger.ticket_type_improvement.last
      expect(result[:detected]).to eq(1)
      expect(ticket.linked_kpis).to include("rule" => "missing_kpi_definition", "keys" => %w[kpi:a kpi:b])
      expect(ticket.title).to include("(2 keys)")
    end

    it "triggers stale_service rule per stale service" do
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      ServiceLedger.create!(service_id: "ai_sns", scope_level: :service, business_owner: "owner", status: :active)
      ServiceLedger.create!(service_id: "trade_ops", scope_level: :service, business_owner: "owner", status: :active)
      create(:meeting_ledger,
             meeting_definition: weekly_definition,
             meeting_key: "weekly_dept",
             service_id: "trade_ops",
             held_at: 1.day.ago,
             status: :closed)

      result = described_class.call

      expect(result[:detected]).to eq(1)
      ticket = TicketLedger.ticket_type_improvement.last
      expect(ticket.title).to include("Stale service - ai_sns")
      expect(ticket.linked_kpis).to include("rule" => "stale_service", "service_id" => "ai_sns")
    end

    it "triggers monthly_hold_accumulation rule" do
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      create(:meeting_ledger,
             meeting_definition: monthly_definition,
             meeting_key: "monthly_ops",
             hold_items: [ { reason: "a" }, { reason: "b" }, { reason: "c" } ],
             status: :closed)

      result = described_class.call

      expect(result[:detected]).to eq(1)
      ticket = TicketLedger.ticket_type_improvement.last
      expect(ticket.linked_kpis).to include("rule" => "monthly_hold_accumulation", "hold_count" => 3)
    end

    it "does not create duplicate improvement ticket for same rule" do
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      create(:ticket_ledger, ticket_type: :improvement, status: :waiting_review, linked_kpis: { rule: "high_overdue_rate" })
      create_list(:ticket_ledger, 4, status: :approved, created_at: 2.days.ago)
      create_list(:ticket_ledger, 2, status: :overdue, created_at: 2.days.ago)

      expect { described_class.call }.not_to change(TicketLedger.ticket_type_improvement, :count)
    end

    it "does not create ticket when conditions are not met" do
      ServiceLedger.create!(service_id: "ai_sns", scope_level: :service, business_owner: "owner", status: :active)
      create(:meeting_ledger,
             meeting_definition: weekly_definition,
             meeting_key: "weekly_dept",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      create(:meeting_ledger,
             meeting_definition: monthly_definition,
             meeting_key: "monthly_ops",
             hold_items: [ { reason: "a" }, { reason: "b" } ],
             status: :closed)
      create(:meeting_ledger,
             meeting_definition: ui_check_definition,
             meeting_key: "ui_check",
             service_id: "ai_sns",
             held_at: 1.day.ago,
             status: :closed)
      create_list(:ticket_ledger, 5, status: :approved, created_at: 2.days.ago)

      result = described_class.call

      expect(result[:detected]).to eq(0)
      expect(TicketLedger.ticket_type_improvement).to be_empty
      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end

    describe "detect_stale_ui_check" do
      it "triggers stale_ui_check rule when ui_check meeting not held within threshold" do
        MeetingLedger.where(meeting_key: "ui_check", service_id: "ai_sns").delete_all
        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.last
        expect(result[:detected]).to be >= 1
        stale_ticket = TicketLedger.ticket_type_improvement.find { |t| t.linked_kpis["rule"] == "stale_ui_check" }
        expect(stale_ticket).to be_present
        expect(stale_ticket.title).to include("ai_sns")
        expect(stale_ticket.service_id).to eq("ai_sns")
        expect(stale_ticket.linked_kpis).to include("rule" => "stale_ui_check", "service_id" => "ai_sns")
      end

      it "does not create ticket when ui_check was recently held" do
        create(:meeting_ledger,
               meeting_definition: ui_check_definition,
               meeting_key: "ui_check",
               service_id: "ai_sns",
               held_at: 1.day.ago,
               status: :closed)

        result = described_class.call

        stale_ticket = TicketLedger.ticket_type_improvement.find { |t| t.linked_kpis["rule"] == "stale_ui_check" }
        expect(stale_ticket).to be_nil
      end

      it "does not create duplicate ticket when stale_ui_check is already open" do
        MeetingLedger.where(meeting_key: "ui_check", service_id: "ai_sns").delete_all
        existing = create(:ticket_ledger,
                          ticket_type: :improvement,
                          status: :waiting_review,
                          linked_kpis: { rule: "stale_ui_check", service_id: "ai_sns" })

        expect { described_class.call }
          .not_to change { TicketLedger.ticket_type_improvement.where(linked_kpis: { rule: "stale_ui_check" }).count }
      end
    end

    describe "detect_persistent_job_failures" do
      def create_solid_queue_failure(class_name:, created_at: Time.current, error: "RuntimeError: boom")
        job = SolidQueue::Job.create!(
          class_name: class_name,
          arguments: "[]",
          queue_name: "default",
          active_job_id: SecureRandom.uuid
        )
        SolidQueue::FailedExecution.create!(job_id: job.id, error: error, created_at: created_at)
      end

      it "triggers persistent_job_failure rule when job fails threshold times in window" do
        3.times { create_solid_queue_failure(class_name: "CommunityDetectJob") }

        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find { |t| t.linked_kpis["rule"] == "persistent_job_failure" }
        expect(ticket).to be_present
        expect(ticket.linked_kpis).to include(
          "rule" => "persistent_job_failure",
          "job_class" => "CommunityDetectJob",
          "window_hours" => Ledgers::ImprovementDetector::JOB_FAILURE_WINDOW_HOURS
        )
        expect(ticket.linked_kpis["failure_count"]).to be >= Ledgers::ImprovementDetector::JOB_FAILURE_COUNT_THRESHOLD
        expect(ticket.title).to include("CommunityDetectJob")
        expect(result[:detected]).to be >= 1
      end

      it "does not trigger when failures are below threshold" do
        2.times { create_solid_queue_failure(class_name: "CommunityDetectJob") }

        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find { |t| t.linked_kpis["rule"] == "persistent_job_failure" }
        expect(ticket).to be_nil
      end

      it "does not trigger for failures outside the time window" do
        window = Ledgers::ImprovementDetector::JOB_FAILURE_WINDOW_HOURS
        3.times { create_solid_queue_failure(class_name: "CommunityDetectJob", created_at: (window + 1).hours.ago) }

        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find { |t| t.linked_kpis["rule"] == "persistent_job_failure" }
        expect(ticket).to be_nil
      end

      it "does not create duplicate ticket when persistent_job_failure is already open" do
        create(:ticket_ledger,
               ticket_type: :improvement,
               status: :waiting_review,
               linked_kpis: { rule: "persistent_job_failure", job_class: "CommunityDetectJob" })
        3.times { create_solid_queue_failure(class_name: "CommunityDetectJob") }

        before_count = TicketLedger.ticket_type_improvement.count
        described_class.call
        after_count = TicketLedger.ticket_type_improvement.count
        expect(after_count).to eq(before_count)
      end

      it "creates separate tickets for different failing job classes" do
        3.times { create_solid_queue_failure(class_name: "CommunityDetectJob") }
        3.times { create_solid_queue_failure(class_name: "RelationshipDecayJob") }

        described_class.call

        failure_tickets = TicketLedger.ticket_type_improvement.select { |t| t.linked_kpis["rule"] == "persistent_job_failure" }
        job_classes = failure_tickets.map { |t| t.linked_kpis["job_class"] }
        expect(job_classes).to include("CommunityDetectJob", "RelationshipDecayJob")
      end
    end
  end
end
