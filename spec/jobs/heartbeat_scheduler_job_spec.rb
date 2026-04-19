require "rails_helper"

RSpec.describe HeartbeatSchedulerJob, type: :job do
  let(:meeting_def) do
    MeetingDefinition.create!(
      meeting_key: "weekly_dept",
      meeting_type: :weekly,
      scope_level: :service,
      service_id: "ai_sns",
      chair_role: "business_owner",
      participant_roles: %w[planning dev]
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

  describe "#perform" do
    it "enqueues jobs for due heartbeats and advances next_run_at" do
      expect {
        described_class.new.perform
      }.to have_enqueued_job(WeeklyDeptLedgerRunJob).with("ai_sns")

      heartbeat.reload
      expect(heartbeat.next_run_at).to be > Time.current
      expect(heartbeat.last_run_at).to be_within(5.seconds).of(Time.current)
    end

    it "does not enqueue jobs for future heartbeats" do
      heartbeat.update!(next_run_at: 1.hour.from_now)

      expect {
        described_class.new.perform
      }.not_to have_enqueued_job(WeeklyDeptLedgerRunJob)
    end

    it "does not enqueue jobs for paused heartbeats" do
      heartbeat.update!(status: :paused)

      expect {
        described_class.new.perform
      }.not_to have_enqueued_job(WeeklyDeptLedgerRunJob)
    end

    it "returns 0 in dry_run mode without enqueuing" do
      count = nil
      expect {
        count = described_class.new.perform(dry_run: true)
      }.not_to have_enqueued_job(WeeklyDeptLedgerRunJob)

      expect(count).to eq(1)
    end

    it "skips heartbeats without matching schedule definition" do
      schedule_def.destroy!

      expect {
        described_class.new.perform
      }.not_to have_enqueued_job(WeeklyDeptLedgerRunJob)
    end
  end
end
