require "rails_helper"

RSpec.describe WeeklyKpiSnapshotJob, type: :job do
  describe "#perform" do
    it "calls KpiSnapshot.record_weekly!" do
      snap = instance_double(KpiSnapshot, recorded_on: Date.current)
      allow(KpiSnapshot).to receive(:record_weekly!).and_return(snap)

      described_class.perform_now

      expect(KpiSnapshot).to have_received(:record_weekly!)
    end

    it "logs warning when snapshot creation fails" do
      allow(KpiSnapshot).to receive(:record_weekly!).and_return(nil)
      expect(Rails.logger).to receive(:warn).with(/WeeklyKpiSnapshotJob/)

      described_class.perform_now
    end
  end
end
