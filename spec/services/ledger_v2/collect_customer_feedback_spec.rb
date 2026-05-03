require "rails_helper"

RSpec.describe LedgerV2::CollectCustomerFeedback, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }
  let(:since_at) { Time.current.beginning_of_day }

  def call_collector(period: :daily, since_at: self.since_at)
    described_class.call(run: run, period: period, since_at: since_at)
  end

  describe ".call" do
    context "フィードバックデータが存在しない場合" do
      it "2 件の MetricSnapshot を返す（new_count / escalated_count）" do
        snapshots = call_collector
        expect(snapshots.size).to eq(2)
      end

      it "MetricSnapshot が 2 件 DB に保存される" do
        expect { call_collector }.to change(LedgerV2::MetricSnapshot, :count).by(2)
      end

      it "metric_name に customer_feedback_new_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("customer_feedback_new_count")
      end

      it "metric_name に customer_feedback_escalated_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("customer_feedback_escalated_count")
      end

      it "値がすべて 0 になる（データなし）" do
        snapshots = call_collector
        expect(snapshots.map(&:value)).to all(eq(0))
      end
    end

    context "new_feedback ステータスのフィードバックが存在する場合" do
      before { create_list(:customer_feedback_ledger, 3, status: :new_feedback) }

      it "customer_feedback_new_count が 3 になる" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "customer_feedback_new_count" }
        expect(snap.value).to eq(3)
      end
    end

    context "escalated ステータスのフィードバックが period 内に存在する場合" do
      before do
        create_list(:customer_feedback_ledger, 2, status: :escalated, received_at: since_at + 1.hour)
      end

      it "customer_feedback_escalated_count が 2 になる" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "customer_feedback_escalated_count" }
        expect(snap.value).to eq(2)
      end
    end

    context "escalated フィードバックが period 外（since_at より前）の場合" do
      before do
        create(:customer_feedback_ledger, status: :escalated, received_at: since_at - 1.day)
      end

      it "customer_feedback_escalated_count は 0 になる（period 外は集計しない）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "customer_feedback_escalated_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "readonly の保証" do
      it "CustomerFeedbackLedger へ書き込みを行わない" do
        expect { call_collector }.not_to change(CustomerFeedbackLedger, :count)
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
          "customer_feedback_new_count",
          "customer_feedback_escalated_count"
        )
      end
    end
  end
end
