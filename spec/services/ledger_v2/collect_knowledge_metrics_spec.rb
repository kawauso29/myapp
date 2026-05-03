require "rails_helper"

RSpec.describe LedgerV2::CollectKnowledgeMetrics, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }
  let(:since_at) { Time.current.beginning_of_day }

  def call_collector(period: :daily, since_at: self.since_at)
    described_class.call(run: run, period: period, since_at: since_at)
  end

  describe ".call" do
    context "KnowledgeLedger データが存在しない場合" do
      it "2 件の MetricSnapshot を返す（incident_count / stale_draft_count）" do
        snapshots = call_collector
        expect(snapshots.size).to eq(2)
      end

      it "MetricSnapshot が 2 件 DB に保存される" do
        expect { call_collector }.to change(LedgerV2::MetricSnapshot, :count).by(2)
      end

      it "metric_name に knowledge_incident_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("knowledge_incident_count")
      end

      it "metric_name に knowledge_stale_draft_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("knowledge_stale_draft_count")
      end

      it "値がすべて 0 になる（データなし）" do
        snapshots = call_collector
        expect(snapshots.map(&:value)).to all(eq(0))
      end
    end

    context "period 内に incident 種別の knowledge_ledger が存在する場合" do
      before do
        create_list(:knowledge_ledger, 2, kind: :incident, status: :accepted, created_at: since_at + 1.hour)
      end

      it "knowledge_incident_count が 2 になる" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "knowledge_incident_count" }
        expect(snap.value).to eq(2)
      end
    end

    context "period 外（since_at より前）に作成された incident の場合" do
      before do
        create(:knowledge_ledger, kind: :incident, status: :accepted, created_at: since_at - 1.day)
      end

      it "knowledge_incident_count は 0 になる（period 外は集計しない）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "knowledge_incident_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "incident 以外の kind（adr, runbook）が period 内にある場合" do
      before do
        create(:knowledge_ledger, kind: :adr,     status: :accepted, created_at: since_at + 1.hour)
        create(:knowledge_ledger, kind: :runbook,  status: :accepted, created_at: since_at + 1.hour)
      end

      it "knowledge_incident_count は 0 のまま（incident のみカウント）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "knowledge_incident_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "7 日以上前に作成された draft が存在する場合" do
      before do
        create_list(:knowledge_ledger, 3, kind: :adr, status: :draft,
                    created_at: since_at - 8.days)
      end

      it "knowledge_stale_draft_count が 3 になる" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "knowledge_stale_draft_count" }
        expect(snap.value).to eq(3)
      end
    end

    context "draft だが 7 日未満（新しい draft）の場合" do
      before do
        create(:knowledge_ledger, kind: :adr, status: :draft,
               created_at: since_at - 3.days)
      end

      it "knowledge_stale_draft_count は 0 のまま（新しい draft は stale 扱いしない）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "knowledge_stale_draft_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "accepted ステータスで古いエントリの場合" do
      before do
        create(:knowledge_ledger, kind: :adr, status: :accepted, created_at: since_at - 30.days)
      end

      it "knowledge_stale_draft_count は 0 のまま（accepted は stale 対象外）" do
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "knowledge_stale_draft_count" }
        expect(snap.value).to eq(0)
      end
    end

    context "readonly の保証" do
      it "KnowledgeLedger へ書き込みを行わない" do
        expect { call_collector }.not_to change(KnowledgeLedger, :count)
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
          "knowledge_incident_count",
          "knowledge_stale_draft_count"
        )
      end
    end
  end
end
