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

    context "error isolation" do
      it "does not raise when a heartbeat raises an unexpected error" do
        job = described_class.new
        allow(job).to receive(:find_schedule_for).and_raise(StandardError, "simulated DB error")

        expect { job.perform }.not_to raise_error
      end

      it "returns 0 scheduled when all heartbeat processing fails" do
        job = described_class.new
        allow(job).to receive(:find_schedule_for).and_raise(StandardError, "simulated DB error")

        expect(job.perform).to eq(0)
      end

      it "continues processing remaining heartbeats after one raises an error" do
        another_meeting = MeetingDefinition.create!(
          meeting_key: "monthly_ops",
          meeting_type: :monthly,
          scope_level: :company,
          chair_role: "ceo"
        )
        bad_heartbeat = ServiceHeartbeat.create!(
          meeting_definition: another_meeting,
          service_id: nil,
          due_cycle: :monthly,
          status: :active,
          next_run_at: 2.hours.ago
        )

        job = described_class.new
        bad_id = bad_heartbeat.id
        allow(job).to receive(:find_schedule_for).and_wrap_original do |original, hb|
          raise StandardError, "simulated error" if hb.id == bad_id
          original.call(hb)
        end

        result = job.perform
        # bad_heartbeat raises -> rescue; heartbeat (with schedule) succeeds
        expect(result).to eq(1)
        expect(WeeklyDeptLedgerRunJob).to have_received(:perform_later).with("ai_sns")
      end
    end

    context "when service_id is nil" do
      let(:company_meeting_def) do
        MeetingDefinition.create!(
          meeting_key: "monthly_ops",
          meeting_type: :monthly,
          scope_level: :company,
          chair_role: "ceo"
        )
      end

      let!(:company_schedule_def) do
        ServiceScheduleDefinition.create!(
          job_key: "monthly_ops_ledger_run",
          job_class: "MonthlyOpsLedgerRunJob",
          cron: "0 */12 * * *",
          cadence: :monthly,
          args: [],
          enabled: true
        )
      end

      let!(:company_heartbeat) do
        ServiceHeartbeat.create!(
          meeting_definition: company_meeting_def,
          service_id: nil,
          due_cycle: :monthly,
          status: :active,
          next_run_at: 1.hour.ago
        )
      end

      before do
        allow(MonthlyOpsLedgerRunJob).to receive(:perform_later)
      end

      it "matches the schedule without service_id suffix" do
        described_class.new.perform

        expect(MonthlyOpsLedgerRunJob).to have_received(:perform_later)
      end

      it "does not treat a trailing-colon job_key as a valid candidate" do
        # Create a schedule only with the malformed trailing-colon key
        # The old code generated ["monthly_ops_ledger_run:", "monthly_ops_ledger_run"] as candidates,
        # so the colon key could accidentally match. The fix generates only ["monthly_ops_ledger_run"].
        colon_schedule = ServiceScheduleDefinition.create!(
          job_key: "monthly_ops_ledger_run:",
          job_class: "MonthlyOpsLedgerRunJob",
          cron: "0 */12 * * *",
          cadence: :monthly,
          args: [],
          enabled: true
        )
        company_schedule_def.destroy!

        described_class.new.perform

        expect(MonthlyOpsLedgerRunJob).not_to have_received(:perform_later)
      ensure
        colon_schedule&.destroy
      end
    end
  end
end
