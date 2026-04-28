require "rails_helper"

RSpec.describe LedgerV2::DetectMetricAnomalies, type: :service do
  # 検査対象のスナップショットを手軽に作るヘルパー
  def build_snap(metric_name:, value:, period: :daily, measured_at: Time.current, unit: nil)
    LedgerV2::MetricSnapshot.new(
      metric_name: metric_name,
      value:       value,
      period:      period,
      measured_at: measured_at,
      unit:        unit
    )
  end

  describe ".call" do
    context "スナップショットがすべて正常範囲内の場合" do
      it "空の配列を返す" do
        snapshots = [
          build_snap(metric_name: "ai_sns_posts_count", value: 10),
          build_snap(metric_name: "ci_success_rate",    value: 0.95)
        ]
        result = described_class.call(snapshots: snapshots)
        expect(result).to be_empty
      end
    end

    context "スナップショットが空の場合" do
      it "空の配列を返す" do
        expect(described_class.call(snapshots: [])).to be_empty
      end
    end

    context "未知の metric_name の場合" do
      it "検知せずに空の配列を返す" do
        snap = build_snap(metric_name: "unknown_metric", value: 0)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    context "DB に書き込まない（副作用なし）" do
      it "Ticket を作成しない" do
        snap = build_snap(metric_name: "ai_sns_posts_count", value: 0)
        expect {
          described_class.call(snapshots: [snap])
        }.not_to change(LedgerV2::Ticket, :count)
      end

      it "Event を作成しない" do
        snap = build_snap(metric_name: "error_count", value: 999)
        expect {
          described_class.call(snapshots: [snap])
        }.not_to change(LedgerV2::Event, :count)
      end
    end

    # ----- 各 metric_name ルールの検証 -----

    context "ai_sns_posts_count" do
      it "閾値（5）未満のとき Anomaly を返す" do
        snap = build_snap(metric_name: "ai_sns_posts_count", value: 3)
        result = described_class.call(snapshots: [snap])
        expect(result.length).to eq(1)
        expect(result.first.metric_name).to eq("ai_sns_posts_count")
        expect(result.first.anomaly_type).to eq("below_minimum")
        expect(result.first.severity).to eq(:medium)
      end

      it "閾値（5）ちょうどのときは正常扱い" do
        snap = build_snap(metric_name: "ai_sns_posts_count", value: 5)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end

      it "閾値を超えていれば正常扱い" do
        snap = build_snap(metric_name: "ai_sns_posts_count", value: 100)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    context "ai_sns_dm_count" do
      it "1 未満のとき Anomaly を返す" do
        snap = build_snap(metric_name: "ai_sns_dm_count", value: 0)
        result = described_class.call(snapshots: [snap])
        expect(result.length).to eq(1)
        expect(result.first.severity).to eq(:low)
      end

      it "1 以上なら正常扱い" do
        snap = build_snap(metric_name: "ai_sns_dm_count", value: 1)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    context "error_count" do
      it "閾値（10）超過のとき Anomaly を返す" do
        snap = build_snap(metric_name: "error_count", value: 11)
        result = described_class.call(snapshots: [snap])
        expect(result.length).to eq(1)
        expect(result.first.anomaly_type).to eq("exceeded_threshold")
        expect(result.first.severity).to eq(:high)
      end

      it "閾値（10）ちょうどなら正常扱い" do
        snap = build_snap(metric_name: "error_count", value: 10)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    context "ci_success_rate" do
      it "0.8 未満のとき Anomaly を返す" do
        snap = build_snap(metric_name: "ci_success_rate", value: 0.75)
        result = described_class.call(snapshots: [snap])
        expect(result.length).to eq(1)
        expect(result.first.severity).to eq(:high)
      end

      it "0.8 ちょうどなら正常扱い" do
        snap = build_snap(metric_name: "ci_success_rate", value: 0.8)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    context "open_ticket_count" do
      it "20 超過のとき Anomaly を返す" do
        snap = build_snap(metric_name: "open_ticket_count", value: 21)
        result = described_class.call(snapshots: [snap])
        expect(result.length).to eq(1)
        expect(result.first.severity).to eq(:medium)
      end

      it "20 以下なら正常扱い" do
        snap = build_snap(metric_name: "open_ticket_count", value: 20)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    context "artifact_pending_count" do
      it "5 超過のとき Anomaly を返す" do
        snap = build_snap(metric_name: "artifact_pending_count", value: 6)
        result = described_class.call(snapshots: [snap])
        expect(result.length).to eq(1)
        expect(result.first.severity).to eq(:medium)
      end

      it "5 以下なら正常扱い" do
        snap = build_snap(metric_name: "artifact_pending_count", value: 5)
        expect(described_class.call(snapshots: [snap])).to be_empty
      end
    end

    # ----- Anomaly 値オブジェクトの属性検証 -----

    context "Anomaly の canonical_key" do
      it "metric_name / anomaly_type / period / 日付を含む形式になる" do
        measured_at = Time.zone.local(2026, 4, 28, 12, 0, 0)
        snap = build_snap(metric_name: "ai_sns_posts_count", value: 1,
                          period: :daily, measured_at: measured_at)
        anomaly = described_class.call(snapshots: [snap]).first
        expect(anomaly.canonical_key).to eq("ledger_v2:ai_sns_posts_count:below_minimum:daily:2026-04-28")
      end

      it "同じ条件で同じ canonical_key を返す（冪等）" do
        measured_at = Time.zone.local(2026, 4, 28, 9, 0, 0)
        snap1 = build_snap(metric_name: "error_count", value: 50,
                           period: :daily, measured_at: measured_at)
        snap2 = build_snap(metric_name: "error_count", value: 99,
                           period: :daily, measured_at: measured_at)
        anomaly1 = described_class.call(snapshots: [snap1]).first
        anomaly2 = described_class.call(snapshots: [snap2]).first
        expect(anomaly1.canonical_key).to eq(anomaly2.canonical_key)
      end
    end

    context "Anomaly の payload_json" do
      it "value / threshold / direction を含む" do
        snap = build_snap(metric_name: "ai_sns_posts_count", value: 2, unit: "posts")
        anomaly = described_class.call(snapshots: [snap]).first
        expect(anomaly.payload_json["value"]).to eq(2.0)
        expect(anomaly.payload_json["threshold"]).to eq(
          LedgerV2::DetectMetricAnomalies::THRESHOLDS[:ai_sns_posts_count_min]
        )
        expect(anomaly.payload_json["direction"]).to eq("below")
        expect(anomaly.payload_json["unit"]).to eq("posts")
      end
    end

    context "複数の異常が混在する場合" do
      it "すべての異常を返す" do
        snapshots = [
          build_snap(metric_name: "ai_sns_posts_count", value: 1),
          build_snap(metric_name: "error_count",        value: 99),
          build_snap(metric_name: "ci_success_rate",    value: 0.5)
        ]
        result = described_class.call(snapshots: snapshots)
        expect(result.length).to eq(3)
        metric_names = result.map(&:metric_name)
        expect(metric_names).to contain_exactly("ai_sns_posts_count", "error_count", "ci_success_rate")
      end
    end
  end
end
