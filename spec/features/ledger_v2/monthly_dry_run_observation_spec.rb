# Ticket 23: Monthly dry_run 7圧縮日観察
#
# 目的:
#   - MonthlyRunner を dry_run: true で起動し、副作用ゼロのまま実行できることを確認する
#   - Monthly 起因で HealthSnapshot のノイズ率・採用率・失敗率が悪化しないことを検証する
#   - MonthlyRunnerJob がデフォルト dry_run: true で running.yml から起動できることを確認する
#
# 完了の定義（本番環境）:
#   `LedgerV2::HealthSnapshot.count >= 7` かつ `LedgerV2::GraduationCheck.all_pass?` が
#   Monthly dry_run 開始後も維持されることを人間が Dashboard で目視確認する。
#
# 設計の正本: docs/projects/ledger-v2-migration.md §「Ticket 23」
require "rails_helper"

RSpec.describe "LedgerV2 Ticket 23: Monthly dry_run 観察シミュレーション", type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:base_day) { Time.current.beginning_of_day }

  def stub_low_kpi(posts_count: 2, dm_count: 1)
    allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period:, since_at:|
      [
        build_snapshot("ai_sns_posts_count",    posts_count, period, since_at, run),
        build_snapshot("ai_sns_dm_count",       dm_count,    period, since_at, run),
        build_snapshot("ai_sns_reaction_count", 1,           period, since_at, run)
      ]
    end
  end

  def build_snapshot(name, value, period, measured_at, run)
    LedgerV2::MetricSnapshot.find_or_create_by!(
      metric_name: name,
      period:      period,
      measured_at: measured_at,
      source_type: nil,
      source_id:   nil
    ) { |s| s.value = value; s.created_by_run = run }
  end

  def run_daily(offset, dry_run: false)
    travel_to(base_day + offset.hours) do
      LedgerV2::RunExecutor.call("daily_runner",
                                 idempotency_key: "t23_daily_#{offset}",
                                 dry_run:         dry_run)
    end
  end

  def run_weekly(offset, dry_run: false)
    travel_to(base_day + offset.hours) do
      LedgerV2::RunExecutor.call("weekly_runner",
                                 idempotency_key: "t23_weekly_#{offset}",
                                 dry_run:         dry_run)
    end
  end

  def run_monthly(offset, dry_run: true)
    travel_to(base_day + offset.hours) do
      LedgerV2::RunExecutor.call("monthly_runner",
                                 idempotency_key: "t23_monthly_#{offset}",
                                 dry_run:         dry_run)
    end
  end

  def take_health_snapshot(offset)
    travel_to(base_day + offset.hours) do
      LedgerV2::CalculateHealthSnapshot.call(period: :daily)
    end
  end

  before do
    stub_low_kpi
    allow_any_instance_of(LedgerV2::DailyRunner).to receive(:error_count).and_return(0)
    allow_any_instance_of(LedgerV2::DailyRunner).to receive(:ci_success_rate).and_return(1.0)
  end

  # -----------------------------------------------------------------------
  # MonthlyRunner 単体の dry_run 動作確認
  # -----------------------------------------------------------------------
  describe "MonthlyRunner dry_run 単体テスト" do
    before do
      # Monthly に必要な Weekly Artifact を事前に作成する
      run_daily(0)
      run_weekly(4)
    end

    it "MonthlyRunner を dry_run: true で実行すると success になる" do
      result = run_monthly(12)

      expect(result.status).to eq("success")
      expect(result.dry_run).to be true
    end

    it "MonthlyRunner dry_run は DB に Artifact を保存しない" do
      artifact_count_before = LedgerV2::Artifact.where(artifact_type: "monthly_review").count

      run_monthly(12)

      expect(LedgerV2::Artifact.where(artifact_type: "monthly_review").count)
        .to eq(artifact_count_before)
    end

    it "MonthlyRunner dry_run は Ticket を変更しない" do
      ticket_count_before = LedgerV2::Ticket.count

      run_monthly(12)

      expect(LedgerV2::Ticket.count).to eq(ticket_count_before)
    end

    it "MonthlyRunner dry_run: false を渡すと ArgumentError が発生する" do
      expect do
        LedgerV2::MonthlyRunner.call(
          run: instance_double(LedgerV2::Run),
          dry_run: false
        )
      end.to raise_error(ArgumentError, /dry_run: true のみ許可/)
    end
  end

  # -----------------------------------------------------------------------
  # Monthly dry_run 込みの 7圧縮日シミュレーション
  # -----------------------------------------------------------------------
  describe "7圧縮日シミュレーション（Daily × 7 + Weekly × 1 + Monthly × 1 + HealthSnapshot × 7）" do
    before do
      # 7 daily runs（圧縮時間軸: 30分毎 → 3.5時間分）
      7.times { |i| run_daily(i * 0.5) }

      # 1 weekly run（圧縮時間軸: 4時間）
      run_weekly(4)

      # 1 monthly run（dry_run: true、圧縮時間軸: 12時間）
      run_monthly(12)

      # HealthSnapshot を 7 件取得（0.5h 刻みで）
      7.times { |i| take_health_snapshot(i * 0.5) }
    end

    it "MonthlyRunner は dry_run: true で success になる" do
      monthly_run = LedgerV2::Run.where(runner_name: "MonthlyRunner").order(:created_at).last
      expect(monthly_run).not_to be_nil
      expect(monthly_run.status).to eq("success")
      expect(monthly_run.dry_run).to be true
    end

    it "HealthSnapshot が 7 件以上存在する（卒業基準 #6 を維持）" do
      expect(LedgerV2::HealthSnapshot.count).to be >= 7
    end

    it "Monthly dry_run 後も Runner 失敗率が 0.05 以下（卒業基準 #3 を維持）" do
      snapshot = LedgerV2::HealthSnapshot.order(measured_at: :desc).first
      expect(snapshot).not_to be_nil
      expect(snapshot.runner_failure_rate).to be <= 0.05
    end

    it "Monthly dry_run 後も pending_review_count が 20 以下（卒業基準 #7 を維持）" do
      snapshot = LedgerV2::HealthSnapshot.order(measured_at: :desc).first
      pending_count = snapshot&.pending_review_count ||
                      LedgerV2::Artifact.awaiting_review.count
      expect(pending_count).to be <= 20
    end

    it "MonthlyRunner dry_run は Artifact を DB に保存しない" do
      expect(LedgerV2::Artifact.where(artifact_type: "monthly_review").count).to eq(0)
    end

    it "GraduationCheck が Monthly dry_run 後も all_pass? を維持できる状態にある" do
      results = LedgerV2::GraduationCheck.call

      # #3 Runner 失敗率 <= 0.05
      runner_failure = results.find { |r| r.key == :runner_failure_rate }
      expect(runner_failure.ok?).to be true

      # #6 HealthSnapshot >= 7
      snapshot_count = results.find { |r| r.key == :health_snapshot_count }
      expect(snapshot_count.ok?).to be true

      # #7 pending <= 20
      pending = results.find { |r| r.key == :pending_review_count }
      expect(pending.ok?).to be true
    end
  end

  # -----------------------------------------------------------------------
  # MonthlyRunnerJob のデフォルト dry_run 確認
  # -----------------------------------------------------------------------
  describe "MonthlyRunnerJob のデフォルト dry_run" do
    it "引数なしで実行すると dry_run: true で RunExecutor を呼ぶ" do
      allow(LedgerV2::RunExecutor).to receive(:call).and_return(instance_double(LedgerV2::Run))

      LedgerV2::MonthlyRunnerJob.perform_now

      expect(LedgerV2::RunExecutor).to have_received(:call).with(
        :monthly_runner,
        hash_including(dry_run: true)
      )
    end
  end
end
