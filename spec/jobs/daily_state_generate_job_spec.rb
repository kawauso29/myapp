require "rails_helper"

RSpec.describe DailyStateGenerateJob, type: :job do
  describe "#perform" do
    let!(:active_ai)   { create(:ai_user, is_active: true) }
    let!(:inactive_ai) { create(:ai_user, is_active: false) }

    before do
      allow(Daily::DailyStateGenerator).to receive(:generate)
    end

    it "calls DailyStateGenerator for each active AI" do
      described_class.new.perform
      expect(Daily::DailyStateGenerator).to have_received(:generate).with(active_ai)
    end

    it "does not call DailyStateGenerator for inactive AIs" do
      described_class.new.perform
      expect(Daily::DailyStateGenerator).not_to have_received(:generate).with(inactive_ai)
    end

    context "when a daily state already exists for today" do
      before do
        create(:ai_daily_state, ai_user: active_ai, date: Date.current)
      end

      it "skips generation" do
        described_class.new.perform
        expect(Daily::DailyStateGenerator).not_to have_received(:generate).with(active_ai)
      end
    end

    context "when generation raises an error for one AI" do
      let!(:other_ai) { create(:ai_user, is_active: true) }

      before do
        allow(Daily::DailyStateGenerator)
          .to receive(:generate).with(active_ai).and_raise(StandardError, "boom")
        allow(Daily::DailyStateGenerator)
          .to receive(:generate).with(other_ai)
      end

      it "continues processing remaining AIs" do
        expect { described_class.new.perform }.not_to raise_error
        expect(Daily::DailyStateGenerator).to have_received(:generate).with(other_ai)
      end
    end
  end
end
