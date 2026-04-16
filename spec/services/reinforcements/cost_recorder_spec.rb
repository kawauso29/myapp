require "rails_helper"

RSpec.describe Reinforcements::CostRecorder do
  describe ".record_job" do
    it "creates a job-scoped cost_ledger row" do
      record = described_class.record_job(
        subject_id: "job-42",
        amount_jpy: 12.5,
        source: :llm_api,
        scope_level: :service,
        service_id: "ai_sns",
        source_detail: "gpt-4o-mini"
      )
      expect(record).to be_persisted
      expect(record.subject_type).to eq("job")
      expect(record.subject_id).to eq("job-42")
      expect(record.amount_jpy).to eq(12.5)
    end
  end

  describe ".record_meeting" do
    it "creates a meeting-scoped cost_ledger row" do
      meeting = create(:meeting_ledger)
      record = described_class.record_meeting(meeting: meeting, amount_jpy: 200)
      expect(record.subject_type).to eq("meeting")
      expect(record.subject_id).to eq(meeting.id.to_s)
      expect(record.source_meeting).to eq(meeting)
    end
  end

  describe ".record_artifact" do
    it "creates an artifact-scoped cost_ledger row" do
      record = described_class.record_artifact(
        artifact_id: "art-1",
        amount_jpy: 5,
        service_id: "ai_sns"
      )
      expect(record.subject_type).to eq("artifact")
      expect(record.source_artifact_id).to eq("art-1")
    end
  end

  describe ".monthly_total" do
    it "sums amount_jpy for the current month scoped by service_id" do
      described_class.record_job(subject_id: "j1", amount_jpy: 10, service_id: "ai_sns",
                                 incurred_at: Time.current.beginning_of_month + 1.day)
      described_class.record_job(subject_id: "j2", amount_jpy: 5, service_id: "ai_sns",
                                 incurred_at: Time.current.beginning_of_month + 2.days)
      described_class.record_job(subject_id: "j3", amount_jpy: 99, service_id: "other",
                                 incurred_at: Time.current.beginning_of_month + 1.day)

      total = described_class.monthly_total(service_id: "ai_sns")
      expect(total).to eq(15)
    end
  end

  describe ".total_for" do
    it "sums by subject_type and subject_id" do
      described_class.record_job(subject_id: "job-1", amount_jpy: 3)
      described_class.record_job(subject_id: "job-1", amount_jpy: 4)
      expect(described_class.total_for(subject_type: :job, subject_id: "job-1")).to eq(7)
    end
  end
end
