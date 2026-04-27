require "rails_helper"

RSpec.describe Ledgers::UiCheckRunner do
  describe ".call" do
    let!(:ui_check_definition) do
      MeetingDefinition.find_or_create_by!(meeting_key: "ui_check") do |d|
        d.meeting_type = :weekly
        d.scope_level = :service
        d.service_id = "ai_sns"
        d.chair_role = "dev"
        d.participant_roles = %w[dev ops audit]
        d.writes_ledgers = %w[meeting_ledger ticket_ledger]
      end
    end

    let!(:ui_screen_kpi) do
      create(:kpi_ledger,
             kpi_key: Ledgers::UiCheckRunner::UI_KPI_KEYS[0],
             scope_level: :service,
             service_id: "ai_sns",
             status: :active,
             current_value: { "value" => 100.0 },
             grade: "healthy")
    end

    let!(:ui_crash_kpi) do
      create(:kpi_ledger,
             kpi_key: Ledgers::UiCheckRunner::UI_KPI_KEYS[1],
             scope_level: :service,
             service_id: "ai_sns",
             status: :active,
             current_value: { "value" => 0.1 },
             grade: "healthy")
    end

    it "creates a ui_check meeting ledger with status :closed" do
      meeting = described_class.call

      expect(meeting).to be_persisted
      expect(meeting.meeting_key).to eq("ui_check")
      expect(meeting).to be_status_closed
      expect(meeting.service_id).to eq("ai_sns")
      expect(meeting.held_at).to be_within(5.seconds).of(Time.current)
    end

    it "sets idempotency_key starting with ui_check:ai_sns:" do
      meeting = described_class.call

      expect(meeting.idempotency_key).to start_with("ui_check:ai_sns:")
    end

    it "records kpi_snapshot in decisions" do
      meeting = described_class.call

      expect(meeting.decisions.first).to include("kpi_snapshot")
      expect(meeting.decisions.first["anomaly_count"]).to eq(0)
    end

    it "records no hold_items when all UI KPIs are healthy" do
      meeting = described_class.call

      expect(meeting.hold_items).to be_empty
    end

    it "records anomaly hold_items for critical UI KPIs" do
      ui_screen_kpi.update!(grade: "critical", current_value: { "value" => 10.0 })

      meeting = described_class.call

      expect(meeting.hold_items).to include(
        a_hash_including("type" => "anomaly", "kpi_key" => Ledgers::UiCheckRunner::UI_KPI_KEYS[0])
      )
      expect(meeting.decisions.first["anomaly_count"]).to eq(1)
    end

    it "generates minutes with ui_check purpose" do
      meeting = described_class.call

      expect(meeting.minutes).to be_a(Hash)
      expect(meeting.minutes["purpose"]).to include("UI チェック")
    end

    it "satisfies ui_check_recent? after execution" do
      described_class.call

      expect(
        MeetingLedger.where(meeting_key: "ui_check", service_id: "ai_sns")
                     .where(held_at: 3.days.ago..Time.current)
                     .exists?
      ).to be true
    end

    it "raises ActiveRecord::RecordNotFound when MeetingDefinition is missing" do
      MeetingDefinition.where(meeting_key: "ui_check").delete_all

      expect { described_class.call }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
