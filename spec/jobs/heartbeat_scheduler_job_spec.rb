require "rails_helper"

RSpec.describe HeartbeatSchedulerJob, type: :job do
  let(:meeting_def) do
    MeetingDefinition.create!(
      meeting_key: "weekly_dept",
      meeting_type: :weekly,
      scope_level: :service,
      service_id: "ai_sns",
      chair_role: "business_owner"
    )
  end

  let!(:schedule_def) do
    ServiceScheduleDefinition.create!(
      job_key: "weekly_dept_ledger_run:ai_sns",
      job_class: "WeeklyDeptLedgerRunJob",
      cron: "0 */4 * * *",
      service_id: "ai_sns",
      cadence: :weekly,
      args: ["ai_sns"],
      enabled: true
    )
  end

  let!(:heartbeat) do
    ServiceHeartbeat.create!(
      meeting_definition: meeting_def,
      service_id: "ai_sns",
      due_cycle: :weekly,
      status: :active,
      next_run_at: 1.hour.ago
    )
  end

  before do
    allow(WeeklyDeptLedgerRunJob).to receive(:perform_later)
  end

  describe "#perform" do
    it "enqueues jobs for due heartbeats and advances next_run_at" do
      described_class.new.perform

      expect(WeeklyDeptLedgerRunJob).to have_received(:perform_later).with("ai_sns")

      heartbeat.reload
      expect(heartbeat.next_run_at).to be > Time.current
      expect(heartbeat.last_run_at).to be_within(5.seconds).of(Time.current)
    end

    it "does not enqueue jobs for future heartbeats" do
      heartbeat.update!(next_run_at: 1.hour.from_now)

      described_class.new.perform

      expect(WeeklyDeptLedgerRunJob).not_to have_received(:perform_later)
    end

    it "does not enqueue jobs for paused heartbeats" do
      heartbeat.update!(status: :paused)

      described_class.new.perform

      expect(WeeklyDeptLedgerRunJob).not_to have_received(:perform_later)
    end

    it "returns scheduled count in dry_run mode without enqueuing" do
      count = described_class.new.perform(dry_run: true)

      expect(count).to eq(1)
      expect(WeeklyDeptLedgerRunJob).not_to have_received(:perform_later)
    end

    it "skips heartbeats without matching schedule definition" do
      schedule_def.destroy!

      described_class.new.perform

      expect(WeeklyDeptLedgerRunJob).not_to have_received(:perform_later)
    end
  end
end
