require "rails_helper"

RSpec.describe LedgerV2::CalculateHealthSnapshotJob, type: :job do
  describe "#perform" do
    it "CalculateHealthSnapshot.call(period: :daily) を呼ぶ" do
      expect(LedgerV2::CalculateHealthSnapshot).to receive(:call).with(period: :daily, dry_run: false)
      described_class.new.perform
    end

    it "period 引数を受け取る" do
      expect(LedgerV2::CalculateHealthSnapshot).to receive(:call).with(period: :weekly, dry_run: false)
      described_class.new.perform(period: :weekly)
    end

    it "dry_run: true を渡せる" do
      expect(LedgerV2::CalculateHealthSnapshot).to receive(:call).with(period: :daily, dry_run: true)
      described_class.new.perform(dry_run: true)
    end

    it "実際に snapshot が 1 件作成される（実行統合）" do
      expect { described_class.new.perform }.to change { LedgerV2::HealthSnapshot.count }.by(1)
    end
  end
end
