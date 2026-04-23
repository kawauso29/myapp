require "rails_helper"

RSpec.describe Ledgers::ImprovementEscalator do
  describe ".call" do
    let!(:monthly_definition) do
      create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil)
    end
    let!(:quarterly_definition) do
      create(
        :meeting_definition,
        meeting_key: "quarterly_review",
        meeting_type: :quarterly_review,
        scope_level: :company,
        service_id: nil
      )
    end
    let!(:monthly_meeting) do
      create(
        :meeting_ledger,
        meeting_definition: monthly_definition,
        meeting_key: "monthly_ops",
        held_at: 1.day.ago,
        status: :closed
      )
    end
    let!(:quarterly_meeting) do
      create(
        :meeting_ledger,
        meeting_definition: quarterly_definition,
        meeting_key: "quarterly_review",
        meeting_type: :quarterly_review,
        held_at: 1.day.ago,
        status: :closed
      )
    end

    before do
      allow(Ledgers::SlackNotifier).to receive(:notify)
    end

    it "marks waiting_review ticket as overdue after 14 days" do
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 14.days.ago,
        linked_kpis: { rule: "high_overdue_rate" }
      )

      result = described_class.call

      expect(ticket.reload).to be_status_overdue
      expect(result[:overdue_marked]).to eq(1)
      expect(result[:details]).to include(a_hash_including(action: "marked_overdue", ticket_id: ticket.id))
    end

    it "creates monthly hold item after 21 days unresolved" do
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 21.days.ago,
        linked_kpis: { rule: "missing_kpi_definition" }
      )

      result = described_class.call
      monthly_hold_items = Array(monthly_meeting.reload.hold_items)

      expect(result[:escalated_monthly]).to eq(1)
      expect(monthly_hold_items).to include(
        a_hash_including(
          "reason" => "improvement_escalation_monthly",
          "ticket_ledger_id" => ticket.id
        )
      )
    end

    it "creates quarterly hold item after 45 days unresolved" do
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :overdue,
        created_at: 45.days.ago,
        linked_kpis: { rule: "stale_service" }
      )

      result = described_class.call
      quarterly_hold_items = Array(quarterly_meeting.reload.hold_items)

      expect(result[:escalated_quarterly]).to eq(1)
      expect(quarterly_hold_items).to include(
        a_hash_including(
          "reason" => "improvement_escalation_quarterly",
          "ticket_ledger_id" => ticket.id
        )
      )
    end

    it "does not create duplicate hold items when called multiple times" do
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 50.days.ago,
        linked_kpis: { rule: "high_overdue_rate" }
      )

      first = described_class.call
      second = described_class.call

      monthly_count = Array(monthly_meeting.reload.hold_items).count do |item|
        item["reason"] == "improvement_escalation_monthly" && item["ticket_ledger_id"] == ticket.id
      end
      quarterly_count = Array(quarterly_meeting.reload.hold_items).count do |item|
        item["reason"] == "improvement_escalation_quarterly" && item["ticket_ledger_id"] == ticket.id
      end

      expect(first[:escalated_monthly]).to eq(1)
      expect(first[:escalated_quarterly]).to eq(1)
      expect(second[:escalated_monthly]).to eq(0)
      expect(second[:escalated_quarterly]).to eq(0)
      expect(monthly_count).to eq(1)
      expect(quarterly_count).to eq(1)
    end

    it "notifies slack only when actions were taken" do
      create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 10.days.ago,
        linked_kpis: { rule: "high_overdue_rate" }
      )

      described_class.call

      expect(Ledgers::SlackNotifier).not_to have_received(:notify)

      create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 30.days.ago,
        linked_kpis: { rule: "high_overdue_rate" }
      )

      described_class.call

      expect(Ledgers::SlackNotifier).to have_received(:notify).with(
        hash_including(
          operation: "escalate_improvements",
          overdue_marked: be >= 1
        )
      )
    end
  end

  describe "create_meeting_if_possible（会議が存在しない場合の緊急作成）" do
    let!(:monthly_definition) do
      create(:meeting_definition, meeting_key: "monthly_ops", meeting_type: :monthly, scope_level: :company, service_id: nil)
    end
    let!(:quarterly_definition) do
      create(
        :meeting_definition,
        meeting_key: "quarterly_review",
        meeting_type: :quarterly_review,
        scope_level: :company,
        service_id: nil
      )
    end

    before do
      allow(Ledgers::SlackNotifier).to receive(:notify)
    end

    it "monthly_ops 会議が未作成でもエスカレーション対象チケットを monthly_ops に hold できる" do
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 21.days.ago,
        linked_kpis: { rule: "stale_service" }
      )

      expect { described_class.call }.to change(MeetingLedger, :count).by(1)

      created_meeting = MeetingLedger.where(meeting_key: "monthly_ops").last
      expect(created_meeting.status).to eq("closed")
      expect(created_meeting.idempotency_key).to be_present
      expect(Array(created_meeting.hold_items)).to include(
        a_hash_including("reason" => "improvement_escalation_monthly", "ticket_ledger_id" => ticket.id)
      )
    end

    it "quarterly_review 会議が未作成でもエスカレーション対象チケットを quarterly_review に hold できる" do
      ticket = create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :overdue,
        created_at: 45.days.ago,
        linked_kpis: { rule: "stale_service" }
      )

      expect { described_class.call }.to change(MeetingLedger.where(meeting_key: "quarterly_review"), :count).by(1)

      created_meeting = MeetingLedger.where(meeting_key: "quarterly_review").last
      expect(created_meeting.idempotency_key).to be_present
    end

    it "同一スロット内で2回呼んでも緊急会議が重複作成されない（idempotency）" do
      create(
        :ticket_ledger,
        ticket_type: :improvement,
        status: :waiting_review,
        created_at: 21.days.ago,
        linked_kpis: { rule: "stale_service" }
      )

      described_class.call
      # 同スロット内の2回目：会議は増えず、hold_items も重複しない
      expect { described_class.call }.not_to change(MeetingLedger.where(meeting_key: "monthly_ops"), :count)

      meeting = MeetingLedger.where(meeting_key: "monthly_ops").last
      escalation_items = Array(meeting.hold_items).select do |item|
        item["reason"] == "improvement_escalation_monthly"
      end
      expect(escalation_items.count).to eq(1)
    end
  end
end
