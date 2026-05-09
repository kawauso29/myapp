require "rails_helper"

RSpec.describe LedgerV2::EvaluateImprovement, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "EvaluateImprovement", trigger_type: :schedule) }

  def call_service(dry_run: false)
    described_class.call(run: run, dry_run: dry_run)
  end

  def create_resolved_ticket(metric_name:, resolved_at: 2.hours.ago, anomaly_type: "exceeded_threshold")
    LedgerV2::Ticket.create!(
      canonical_key:  "test:#{metric_name}:#{SecureRandom.hex(4)}",
      title:          "テストチケット: #{metric_name}",
      status:         :resolved,
      severity:       :medium,
      review_status:  :not_required,
      human_decision: :none,
      metric_name:    metric_name,
      anomaly_type:   anomaly_type,
      created_at:     resolved_at - 1.hour,
      updated_at:     resolved_at
    )
  end

  def create_metric_snapshot(metric_name:, value:, measured_at: 30.minutes.ago)
    LedgerV2::MetricSnapshot.create!(
      metric_name: metric_name,
      value:       value,
      period:      :daily,
      measured_at: measured_at
    )
  end

  describe ".call" do
    context "改善が検知された場合（exceeded_threshold → 正常値に戻った）" do
      it "improvement_detected Event が作成される" do
        ticket = create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        # error_count の閾値は 10。5 は正常範囲内 → improved
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        expect {
          call_service
        }.to change { LedgerV2::Event.where(event_type: "improvement_detected").count }.by(1)
      end

      it "improvement_detected Event の payload_json に ticket_id と metric_name が含まれる" do
        ticket = create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        call_service

        event = LedgerV2::Event.where(event_type: "improvement_detected").last
        expect(event.payload_json["ticket_id"]).to eq(ticket.id)
        expect(event.payload_json["metric_name"]).to eq("error_count")
        expect(event.payload_json["improved"]).to be true
        expect(event.payload_json["current_value"]).to eq(5.0)
        expect(event.payload_json["threshold"]).to eq(10)
      end

      it "RunnerResult の created_event_count が 1 になる" do
        create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        result = call_service
        expect(result.created_event_count).to eq(1)
      end
    end

    context "改善が検知されなかった場合（exceeded_threshold → まだ高い値のまま）" do
      it "improvement_not_detected Event が作成される" do
        create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        # 閾値 10 を超えている → 改善なし
        create_metric_snapshot(metric_name: "error_count", value: 15, measured_at: 1.hour.ago)

        expect {
          call_service
        }.to change { LedgerV2::Event.where(event_type: "improvement_not_detected").count }.by(1)
      end

      it "improvement_not_detected Event の payload_json の improved が false になる" do
        create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 15, measured_at: 1.hour.ago)

        call_service

        event = LedgerV2::Event.where(event_type: "improvement_not_detected").last
        expect(event.payload_json["improved"]).to be false
      end
    end

    context "below_minimum 異常の場合（posts_count < 閾値 → 閾値以上に回復）" do
      it "閾値以上に回復した場合 improvement_detected になる" do
        create_resolved_ticket(
          metric_name: "ai_sns_posts_count",
          anomaly_type: "below_minimum",
          resolved_at: 2.hours.ago
        )
        # 閾値 5。8 は正常範囲 → improved
        create_metric_snapshot(metric_name: "ai_sns_posts_count", value: 8, measured_at: 1.hour.ago)

        expect {
          call_service
        }.to change { LedgerV2::Event.where(event_type: "improvement_detected").count }.by(1)
      end

      it "閾値未満のままなら improvement_not_detected になる" do
        create_resolved_ticket(
          metric_name: "ai_sns_posts_count",
          anomaly_type: "below_minimum",
          resolved_at: 2.hours.ago
        )
        # 閾値 5。3 はまだ低い → not improved
        create_metric_snapshot(metric_name: "ai_sns_posts_count", value: 3, measured_at: 1.hour.ago)

        expect {
          call_service
        }.to change { LedgerV2::Event.where(event_type: "improvement_not_detected").count }.by(1)
      end
    end

    context "冪等性（同一 Ticket に対して評価 Event がすでに存在する場合）" do
      it "同じ Ticket を 2 回呼んでも Event が 1 件しか作成されない" do
        create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        call_service
        expect {
          call_service
        }.not_to change { LedgerV2::Event.count }
      end
    end

    context "評価対象外のケース" do
      it "metric_name が nil の Ticket はスキップされる" do
        LedgerV2::Ticket.create!(
          canonical_key:  "test:no-metric:#{SecureRandom.hex(4)}",
          title:          "metric なしチケット",
          status:         :resolved,
          severity:       :medium,
          review_status:  :not_required,
          human_decision: :none
        )

        expect {
          call_service
        }.not_to change { LedgerV2::Event.count }
      end

      it "open 状態の Ticket はスキップされる" do
        LedgerV2::Ticket.create!(
          canonical_key:  "test:open:#{SecureRandom.hex(4)}",
          title:          "オープンチケット",
          status:         :open,
          severity:       :medium,
          review_status:  :not_required,
          human_decision: :none,
          metric_name:    "error_count"
        )
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        expect {
          call_service
        }.not_to change { LedgerV2::Event.count }
      end

      it "resolved 後に MetricSnapshot がまだない Ticket はスキップされる" do
        # resolved_at を未来に設定 → その後の snapshot が存在しない
        ticket = create_resolved_ticket(metric_name: "error_count", resolved_at: 10.minutes.ago)
        # snapshot は ticket よりも前に存在する（対象外）
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        expect {
          call_service
        }.not_to change { LedgerV2::Event.count }
      end

      it "METRIC_CONFIG に登録されていない metric_name はスキップされる" do
        create_resolved_ticket(metric_name: "unknown_metric", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "unknown_metric", value: 100, measured_at: 1.hour.ago)

        expect {
          call_service
        }.not_to change { LedgerV2::Event.count }
      end
    end

    context "dry_run: true の場合" do
      it "Event が作成されない" do
        create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        expect {
          call_service(dry_run: true)
        }.not_to change { LedgerV2::Event.count }
      end

      it "RunnerResult の created_event_count が 0 になる（dry_run は記録しない）" do
        create_resolved_ticket(metric_name: "error_count", resolved_at: 2.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 1.hour.ago)

        result = call_service(dry_run: true)
        expect(result.created_event_count).to eq(0)
      end
    end

    context "複数の Ticket を一度に評価する場合" do
      it "改善済みと未改善の両方を正しく集計する" do
        # Ticket 1: error_count → 改善済み
        create_resolved_ticket(metric_name: "error_count", resolved_at: 3.hours.ago)
        create_metric_snapshot(metric_name: "error_count", value: 5, measured_at: 2.hours.ago)

        # Ticket 2: open_ticket_count → まだ多い（改善なし）
        create_resolved_ticket(metric_name: "open_ticket_count", resolved_at: 3.hours.ago)
        create_metric_snapshot(metric_name: "open_ticket_count", value: 25, measured_at: 2.hours.ago)

        result = call_service
        expect(result.created_event_count).to eq(2)
        expect(LedgerV2::Event.where(event_type: "improvement_detected").count).to eq(1)
        expect(LedgerV2::Event.where(event_type: "improvement_not_detected").count).to eq(1)
      end
    end

    context "METRIC_CONFIG の全 metric_name が正しく設定されている" do
      described_class::METRIC_CONFIG.each do |metric_name, config|
        it "#{metric_name} の threshold_key が DetectMetricAnomalies::THRESHOLDS に存在する" do
          threshold = LedgerV2::DetectMetricAnomalies::THRESHOLDS[config[:threshold_key]]
          expect(threshold).not_to be_nil,
            "#{metric_name} の threshold_key :#{config[:threshold_key]} が THRESHOLDS に存在しません"
        end

        it "#{metric_name} の direction が :min または :max のどちらかである" do
          expect(%i[min max]).to include(config[:direction])
        end
      end
    end
  end
end
