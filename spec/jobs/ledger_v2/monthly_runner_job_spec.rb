require "rails_helper"

RSpec.describe LedgerV2::MonthlyRunnerJob, type: :job do
  describe "#perform" do
    it "RunExecutor.call を :monthly_runner で呼ぶ" do
      run = instance_double(LedgerV2::Run)
      allow(LedgerV2::RunExecutor).to receive(:call).and_return(run)

      described_class.perform_now

      expect(LedgerV2::RunExecutor).to have_received(:call).with(
        :monthly_runner,
        hash_including(dry_run: false, trigger_type: :schedule)
      )
    end

    it "dry_run: true を渡せる" do
      run = instance_double(LedgerV2::Run)
      allow(LedgerV2::RunExecutor).to receive(:call).and_return(run)

      described_class.perform_now(dry_run: true)

      expect(LedgerV2::RunExecutor).to have_received(:call).with(
        :monthly_runner,
        hash_including(dry_run: true)
      )
    end

    it "trigger_type と triggered_by を RunExecutor に渡せる" do
      run = instance_double(LedgerV2::Run)
      allow(LedgerV2::RunExecutor).to receive(:call).and_return(run)

      described_class.perform_now(trigger_type: :manual, triggered_by: "admin")

      expect(LedgerV2::RunExecutor).to have_received(:call).with(
        :monthly_runner,
        hash_including(trigger_type: :manual, triggered_by: "admin")
      )
    end
  end
end
