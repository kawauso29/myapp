require "rails_helper"

RSpec.describe LedgerV2::CollectExperimentMetrics, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }
  let(:since_at) { Time.current.beginning_of_day }

  def call_collector(period: :daily, since_at: self.since_at)
    described_class.call(run: run, period: period, since_at: since_at)
  end

  describe ".call" do
    context "ExperimentLedger データが存在しない場合" do
      it "2 件の MetricSnapshot を返す（active_count / expired_count）" do
        snapshots = call_collector
        expect(snapshots.size).to eq(2)
      end

      it "MetricSnapshot が 2 件 DB に保存される" do
        expect { call_collector }.to change(LedgerV2::MetricSnapshot, :count).by(2)
      end

      it "metric_name に experiment_active_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("experiment_active_count")
      end

      it "metric_name に experiment_expired_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("experiment_expired_count")
      end

      it "値がすべて 0 になる（データなし）" do
        snapshots = call_collector
        expect(snapshots.map(&:value)).to all(eq(0))
      end
    end

    context "期限内の active 実験が 2 件存在する場合" do
      before do
        create_list(:experiment_ledger, 2, status: :active, deadline: 30.days.from_now.to_date)
      end

      it "experiment_active_count が 2 になる" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "experiment_active_count" }
        expect(snap.value).to eq(2)
      end
    end

    context "期限切れ（deadline < 今日）かつ status_active の実験が 3 件存在する場合" do
      before do
        create_list(:experiment_ledger, 3, status: :active, deadline: 1.day.ago.to_date)
      end

      it "experiment_expired_count が 3 になる" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "experiment_expired_count" }
        expect(snap.value).to eq(3)
      end

      it "experiment_active_count は 0 になる（deadline 切れは active に含めない）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "experiment_active_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "status が continued / withdrawn / expired の場合" do
      before do
        create(:experiment_ledger, status: :continued, deadline: 30.days.from_now.to_date)
        create(:experiment_ledger, status: :withdrawn,  deadline: 30.days.from_now.to_date)
        create(:experiment_ledger, status: :expired,    deadline: 1.day.ago.to_date)
      end

      it "experiment_active_count は 0 のまま（active のみカウント）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "experiment_active_count" }
        expect(snap.value).to eq(0)
      end

      it "experiment_expired_count は 0 のまま（status_active のみカウント）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "experiment_expired_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "readonly の保証" do
      it "ExperimentLedger へ書き込みを行わない" do
        expect { call_collector }.not_to change(ExperimentLedger, :count)
      end
    end

    context "period: :weekly の場合" do
      it "period が weekly のスナップショットを保存する" do
        snapshots = call_collector(period: :weekly)
        expect(snapshots.map(&:period).uniq).to eq(["weekly"])
      end
    end

    context "冪等性（同じ条件で 2 回呼んだ場合）" do
      it "2 回目は MetricSnapshot を増やさない" do
        call_collector
        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        expect {
          described_class.call(run: run2, period: :daily, since_at: since_at)
        }.not_to change(LedgerV2::MetricSnapshot, :count)
      end
    end

    context "METRIC_NAMES 定数の整合性" do
      it "METRIC_NAMES に 2 要素が定義されている" do
        expect(described_class::METRIC_NAMES.size).to eq(2)
      end

      it "METRIC_NAMES が期待する名前を含む" do
        expect(described_class::METRIC_NAMES).to include(
          "experiment_active_count",
          "experiment_expired_count"
        )
      end
    end
  end
end
