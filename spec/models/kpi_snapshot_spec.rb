require "rails_helper"

RSpec.describe KpiSnapshot, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:recorded_on) }
    it { is_expected.to validate_inclusion_of(:period).in_array(%w[daily weekly]) }
  end

  describe ".record_weekly!" do
    it "creates a weekly snapshot with metrics from KpiService" do
      fake_metrics = { collected_at: "2026-04-13T00:00:00Z", users: { total: 5, wau: 2 } }
      allow(Admin::KpiService).to receive(:weekly_metrics).and_return(fake_metrics)

      snap = described_class.record_weekly!

      expect(snap).to be_persisted
      expect(snap.period).to eq("weekly")
      expect(snap.recorded_on).to eq(Date.current)
      expect(snap.metrics.deep_symbolize_keys).to eq(fake_metrics)
    end

    it "overwrites existing snapshot for same date" do
      allow(Admin::KpiService).to receive(:weekly_metrics).and_return({ wau: 1 }, { wau: 2 })
      described_class.record_weekly!
      described_class.record_weekly!

      expect(described_class.weekly.where(recorded_on: Date.current).count).to eq(1)
      expect(described_class.weekly.find_by(recorded_on: Date.current).metrics["wau"]).to eq(2)
    end
  end

  describe ".weekly_trend" do
    it "returns snapshots with delta computed from previous week" do
      snap1 = create(:kpi_snapshot, period: "weekly", recorded_on: 14.days.ago.to_date,
                     metrics: { users: { wau: 10, paid: 2 }, posts: { this_week: 50, conversation_rate_pct: 30.0 },
                                engagement: { user_likes_this_week: 100 } })
      snap2 = create(:kpi_snapshot, period: "weekly", recorded_on: 7.days.ago.to_date,
                     metrics: { users: { wau: 15, paid: 3 }, posts: { this_week: 60, conversation_rate_pct: 35.0 },
                                engagement: { user_likes_this_week: 120 } })

      trend = described_class.weekly_trend(periods: 2)

      expect(trend.size).to eq(2)
      expect(trend.first[:delta]).to be_nil  # 最初は前週なし
      expect(trend.last[:delta][:wau][:diff]).to eq(5.0)
      expect(trend.last[:delta][:wau][:pct]).to eq(50.0)
    end
  end
end
