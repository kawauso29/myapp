require "rails_helper"

RSpec.describe LedgerV2::DailyRunner, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }

  def call_runner(dry_run: false)
    described_class.call(run: run, dry_run: dry_run)
  end

  # テスト高速化: DB アクセスが多い KPI 計算メソッドをスタブ
  # AI-SNS 指標は CollectAiSnsMetrics に委譲されているためそちらをスタブする
  # - ai_sns_posts_count: 閾値 5 以上が必要 → 10 を返す
  # - ai_sns_dm_count:    閾値 1 以上が必要 → 5 を返す
  # DB に保存して MetricSnapshot カウントテストと冪等テストが通るようにする
  before do
    allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period: :daily, since_at: Time.current.beginning_of_day, **|
      ai_sns_values = { "ai_sns_posts_count" => 10, "ai_sns_dm_count" => 5, "ai_sns_reaction_count" => 0 }
      ai_sns_values.map do |metric_name, value|
        LedgerV2::MetricSnapshot.find_or_create_by!(
          metric_name: metric_name, period: period,
          measured_at: since_at, source_type: nil, source_id: nil
        ) { |s| s.value = value; s.created_by_run = run }
      end
    end
    allow_any_instance_of(described_class).to receive(:error_count).and_return(0)
    allow_any_instance_of(described_class).to receive(:ci_success_rate).and_return(1.0)
    allow_any_instance_of(described_class).to receive(:open_ticket_count).and_return(0)
    allow_any_instance_of(described_class).to receive(:artifact_pending_count).and_return(0)
  end

  describe ".call" do
    context "全 KPI が正常範囲内の場合（異常なし）" do
      it "RunnerResult を返す" do
        result = call_runner
        expect(result).to be_a(LedgerV2::RunExecutor::RunnerResult)
      end

      it "Ticket を作成しない" do
        expect { call_runner }.not_to change(LedgerV2::Ticket, :count)
      end

      it "created_ticket_count が 0 になる" do
        result = call_runner
        expect(result.created_ticket_count).to eq(0)
      end

      it "MetricSnapshot が 7 件作成される（KPI 数と同じ）" do
        expect { call_runner }.to change(LedgerV2::MetricSnapshot, :count).by(7)
      end
    end

    context "投稿数が閾値未満の場合（異常あり）" do
      before do
        allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period: :daily, since_at: Time.current.beginning_of_day, **|
          ai_sns_values = { "ai_sns_posts_count" => 1, "ai_sns_dm_count" => 5, "ai_sns_reaction_count" => 0 }
          ai_sns_values.map do |metric_name, value|
            LedgerV2::MetricSnapshot.find_or_create_by!(
              metric_name: metric_name, period: period,
              measured_at: since_at, source_type: nil, source_id: nil
            ) { |s| s.value = value; s.created_by_run = run }
          end
        end
      end

      it "Ticket が 1 件作成される" do
        expect { call_runner }.to change(LedgerV2::Ticket, :count).by(1)
      end

      it "created_ticket_count が 1 になる" do
        result = call_runner
        expect(result.created_ticket_count).to eq(1)
      end

      it "作成された Ticket の metric_name が ai_sns_posts_count" do
        call_runner
        ticket = LedgerV2::Ticket.last
        expect(ticket.metric_name).to eq("ai_sns_posts_count")
      end

      it "ticket_opened Event が作成される" do
        expect { call_runner }.to change {
          LedgerV2::Event.where(event_type: "ticket_opened").count
        }.by(1)
      end
    end

    context "複数の KPI が閾値を超えた場合" do
      before do
        allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period: :daily, since_at: Time.current.beginning_of_day, **|
          ai_sns_values = { "ai_sns_posts_count" => 1, "ai_sns_dm_count" => 5, "ai_sns_reaction_count" => 0 }
          ai_sns_values.map do |metric_name, value|
            LedgerV2::MetricSnapshot.find_or_create_by!(
              metric_name: metric_name, period: period,
              measured_at: since_at, source_type: nil, source_id: nil
            ) { |s| s.value = value; s.created_by_run = run }
          end
        end
        allow_any_instance_of(described_class).to receive(:error_count).and_return(99)
      end

      it "複数の Ticket が作成される" do
        expect { call_runner }.to change(LedgerV2::Ticket, :count).by(2)
      end

      it "created_ticket_count が 2 になる" do
        result = call_runner
        expect(result.created_ticket_count).to eq(2)
      end
    end

    context "同じ日に 2 回実行した場合（重複防止）" do
      before do
        allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period: :daily, since_at: Time.current.beginning_of_day, **|
          ai_sns_values = { "ai_sns_posts_count" => 1, "ai_sns_dm_count" => 5, "ai_sns_reaction_count" => 0 }
          ai_sns_values.map do |metric_name, value|
            LedgerV2::MetricSnapshot.find_or_create_by!(
              metric_name: metric_name, period: period,
              measured_at: since_at, source_type: nil, source_id: nil
            ) { |s| s.value = value; s.created_by_run = run }
          end
        end
      end

      it "2 回目の Ticket は作成されない" do
        call_runner  # 1 回目
        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        expect {
          described_class.call(run: run2, dry_run: false)
        }.not_to change(LedgerV2::Ticket, :count)
      end

      it "2 回目の duplicate_prevented_count が 1 になる" do
        call_runner  # 1 回目
        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        result = described_class.call(run: run2, dry_run: false)
        expect(result.duplicate_prevented_count).to eq(1)
      end
    end

    context "dry_run: true の場合" do
      before do
        allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period: :daily, since_at: Time.current.beginning_of_day, **|
          ai_sns_values = { "ai_sns_posts_count" => 1, "ai_sns_dm_count" => 5, "ai_sns_reaction_count" => 0 }
          ai_sns_values.map do |metric_name, value|
            LedgerV2::MetricSnapshot.find_or_create_by!(
              metric_name: metric_name, period: period,
              measured_at: since_at, source_type: nil, source_id: nil
            ) { |s| s.value = value; s.created_by_run = run }
          end
        end
      end

      it "Ticket を作成しない" do
        expect { call_runner(dry_run: true) }.not_to change(LedgerV2::Ticket, :count)
      end

      it "Event を作成しない" do
        expect { call_runner(dry_run: true) }.not_to change(LedgerV2::Event, :count)
      end

      it "RunnerResult を返す" do
        result = call_runner(dry_run: true)
        expect(result).to be_a(LedgerV2::RunExecutor::RunnerResult)
      end
    end
  end

  describe "MetricSnapshot の収集" do
    it "daily 粒度・当日 measured_at のスナップショットを作成する" do
      call_runner
      snap = LedgerV2::MetricSnapshot.where(metric_name: "ai_sns_posts_count").last
      expect(snap.period).to eq("daily")
      expect(snap.measured_at).to be_within(1.second).of(Time.current.beginning_of_day)
    end

    it "同じ日に 2 回実行しても MetricSnapshot は増えない（冪等）" do
      call_runner
      run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
      expect {
        described_class.call(run: run2, dry_run: false)
      }.not_to change(LedgerV2::MetricSnapshot, :count)
    end
  end
end
