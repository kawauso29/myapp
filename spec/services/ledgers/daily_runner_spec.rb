require "rails_helper"

RSpec.describe Ledgers::DailyRunner do
  describe ".call" do
    let!(:daily_definition) do
      create(:meeting_definition,
             meeting_key: "daily",
             meeting_type: :daily,
             scope_level: :service,
             service_id: "ai_sns",
             chair_role: "system",
             participant_roles: [])
    end

    let!(:service_kpi) do
      create(:kpi_ledger,
             kpi_key: "kpi:service_health",
             scope_level: :service,
             service_id: "ai_sns",
             status: :active,
             current_value: { "value" => 0.9 },
             grade: "healthy")
    end

    it "creates a daily meeting ledger with KPI snapshot" do
      meeting = described_class.call(service_id: "ai_sns")

      expect(meeting).to be_persisted
      expect(meeting).to be_meeting_type_daily
      expect(meeting).to be_status_closed
      expect(meeting.idempotency_key).to start_with("daily:ai_sns:")
      expect(meeting.decisions.first).to include("kpi_snapshot")
    end

    it "detects anomalies for critical KPIs" do
      service_kpi.update!(grade: "critical", current_value: { "value" => 0.1 })

      meeting = described_class.call(service_id: "ai_sns")

      expect(meeting.hold_items).to include(a_hash_including("type" => "anomaly", "kpi_key" => "kpi:service_health"))
      expect(meeting.decisions.first["anomaly_count"]).to eq(1)
    end

    it "carries over hold_items from previous daily meeting" do
      previous = described_class.call(service_id: "ai_sns")
      previous.update!(hold_items: [ { "type" => "anomaly", "kpi_key" => "kpi:old_issue" } ],
                       idempotency_key: "daily:ai_sns:old")

      new_meeting = described_class.call(service_id: "ai_sns")

      expect(new_meeting.carry_over_items).to include(a_hash_including("kpi_key" => "kpi:old_issue"))
    end

    it "publishes artifact via RunnerArtifactPublisher" do
      allow(Ledgers::RunnerArtifactPublisher).to receive(:publish_for!)

      described_class.call(service_id: "ai_sns")

      expect(Ledgers::RunnerArtifactPublisher).to have_received(:publish_for!).with(
        meeting: an_instance_of(MeetingLedger),
        runner: :daily,
        service_id: "ai_sns"
      )
    end

    it "uses cadence-based slot for idempotency_key" do
      slot = Ledgers::TimeAxis.slot_token(:daily)
      meeting = described_class.call(service_id: "ai_sns")

      expect(meeting.idempotency_key).to eq("daily:ai_sns:#{slot}")
    end
  end
end
