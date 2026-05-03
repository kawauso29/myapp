# Ticket 18: 7日間の最小運用テスト（dry_run シミュレーション）
#
# 目的:
#   - DailyRunner / WeeklyRunner を 7日間分 DB 内でシミュレートする
#   - MVP 最小完成条件 15項目を総点検する
#
# 動作テスト（本番FeatureFlagを有効化して実際の7日間を回す）は
# 本 spec が通った後に人間が手動で実施する別ステップ。
# 設計の正本: ledger_v2_detailed_design.txt / docs/projects/ledger-v2-migration.md
require "rails_helper"

RSpec.describe "LedgerV2 MVP 最小完成条件 総点検 / Ticket 18: 7日間シミュレーション",
               type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:base_day) { Time.current.beginning_of_day }

  # CollectAiSnsMetrics を制御するスタブ。
  # posts_count: 1 → ai_sns_posts_count < 5（閾値）で異常検知が発火する。
  # dm_count: 0   → ai_sns_dm_count < 1（閾値）で異常検知が発火する。
  def stub_low_kpi(posts_count: 1, dm_count: 0)
    allow(LedgerV2::CollectAiSnsMetrics).to receive(:call) do |run:, period:, since_at:|
      [
        build_metric_snapshot("ai_sns_posts_count",    posts_count, period, since_at, run),
        build_metric_snapshot("ai_sns_dm_count",       dm_count,    period, since_at, run),
        build_metric_snapshot("ai_sns_reaction_count", 0,           period, since_at, run)
      ]
    end
  end

  def build_metric_snapshot(name, value, period, measured_at, run)
    LedgerV2::MetricSnapshot.find_or_create_by!(
      metric_name: name,
      period:      period,
      measured_at: measured_at,
      source_type: nil,
      source_id:   nil
    ) { |s| s.value = value; s.created_by_run = run }
  end

  # RunExecutor 経由で DailyRunner を実行するヘルパー。
  def run_daily_on(day_offset, idempotency_key: nil, dry_run: false)
    travel_to(base_day + day_offset.days) do
      key = idempotency_key || "sim_daily_d#{day_offset}"
      LedgerV2::RunExecutor.call("daily_runner", idempotency_key: key, dry_run: dry_run)
    end
  end

  # RunExecutor 経由で WeeklyRunner を実行するヘルパー。
  def run_weekly_on(day_offset, dry_run: false)
    travel_to(base_day + day_offset.days) do
      LedgerV2::RunExecutor.call("weekly_runner", dry_run: dry_run)
    end
  end

  # 全コンテキスト共通: CollectAiSnsMetrics と外部依存 KPI をスタブする。
  before do
    stub_low_kpi
    allow_any_instance_of(LedgerV2::DailyRunner).to receive(:error_count).and_return(0)
    allow_any_instance_of(LedgerV2::DailyRunner).to receive(:ci_success_rate).and_return(1.0)
  end

  # -----------------------------------------------------------------------
  # 7日間フルシミュレーション（MVP 1〜10, 13, 15 の総点検）
  # -----------------------------------------------------------------------
  describe "7日間シミュレーション（DailyRunner × 7 + WeeklyRunner × 1）" do
    before do
      7.times { |i| run_daily_on(i) }
      run_weekly_on(7)
    end

    # MVP 条件 1: DailyRunner が RunExecutor 経由で動く
    it "MVP 1: DailyRunner が RunExecutor 経由で 7回 success になる" do
      daily_runs = LedgerV2::Run.where(runner_name: "DailyRunner")
      expect(daily_runs.count).to eq(7)
      expect(daily_runs.all? { |r| r.status == "success" }).to be true
    end

    # MVP 条件 2: WeeklyRunner が RunExecutor 経由で動く
    it "MVP 2: WeeklyRunner が RunExecutor 経由で success になる" do
      weekly_run = LedgerV2::Run.find_by(runner_name: "WeeklyRunner")
      expect(weekly_run).to be_present
      expect(weekly_run.status).to eq("success")
    end

    # MVP 条件 3: Run が記録される
    it "MVP 3: Run が記録される（7 DailyRun + 1 WeeklyRun = 8件）" do
      expect(LedgerV2::Run.count).to eq(8)
    end

    # MVP 条件 4: Event が記録される
    it "MVP 4: Event が記録される" do
      expect(LedgerV2::Event.count).to be_positive
    end

    # MVP 条件 5: MetricSnapshot が保存される
    # CollectAiSnsMetrics(3件) + CollectCustomerFeedback(2件) + snapshot_for × 4件(error/ci/open_ticket/artifact_pending) = 9件/日
    it "MVP 5: MetricSnapshot が保存される（9件/日 × 7日 = 63件）" do
      expect(LedgerV2::MetricSnapshot.count).to eq(63)
    end

    # MVP 条件 6: 異常検知ができる（posts_count が閾値を下回っている）
    it "MVP 6: 異常検知ができる（ai_sns_posts_count の Ticket が存在する）" do
      expect(LedgerV2::Ticket.where(metric_name: "ai_sns_posts_count").count).to be >= 1
    end

    # MVP 条件 7: Ticket が作られる
    # Level 3 重複防止により、日付をまたいで同一異常タイプが継続する場合は
    # 新規チケットを作成しない。posts_count + dm_count の 2種のみ作成される。
    it "MVP 7: Ticket が作られる（異常 2種 × Level 3 重複防止で 2件）" do
      expect(LedgerV2::Ticket.count).to eq(2)
    end

    # MVP 条件 9: Artifact draft が作られる
    it "MVP 9: Artifact draft が作られる（weekly_review × 1件）" do
      expect(LedgerV2::Artifact.where(artifact_type: "weekly_review").count).to eq(1)
    end

    # MVP 条件 10: Artifact が人間レビュー待ちになる
    it "MVP 10: Artifact が人間レビュー待ちになる（review_status: pending）" do
      artifact = LedgerV2::Artifact.find_by(artifact_type: "weekly_review")
      expect(artifact.review_status).to eq("pending")
    end

    # MVP 条件 13: Admin UI で状態が見える
    # （詳細な UI 動作は spec/requests/admin/ledger_v2/ Ticket 13〜15 spec で検証済み）
    it "MVP 13: Admin UI に必要なデータが存在する（Run・Ticket・Artifact が 1件以上）" do
      expect(LedgerV2::Run.count).to be_positive
      expect(LedgerV2::Ticket.count).to be_positive
      expect(LedgerV2::Artifact.count).to be_positive
    end

    # MVP 条件 15: v1 と同時に副作用を起こさない
    it "MVP 15: v2 モデルはすべて ledger_v2_ テーブルのみ使用する" do
      v2_models = [
        LedgerV2::Run,
        LedgerV2::Event,
        LedgerV2::Ticket,
        LedgerV2::Artifact,
        LedgerV2::MetricSnapshot,
        LedgerV2::HealthSnapshot,
        LedgerV2::StopCondition
      ]
      v2_models.each do |model|
        expect(model.table_name).to start_with("ledger_v2_"),
          "#{model} が ledger_v2_ 以外のテーブルを使用しています"
      end
    end

    it "MVP 15: v2 の実行は v1 MeetingLedger / TicketLedger に影響しない" do
      expect(MeetingLedger.count).to eq(0)
      expect(TicketLedger.count).to eq(0)
    end
  end

  # -----------------------------------------------------------------------
  # MVP 条件 8: canonical_key で重複 Ticket が防がれる
  # -----------------------------------------------------------------------
  describe "MVP 8: canonical_key で重複 Ticket が防がれる" do
    it "同一日に DailyRunner を 2回実行しても Ticket は増えない" do
      travel_to(base_day) do
        run1 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        LedgerV2::DailyRunner.call(run: run1, dry_run: false)
        tickets_after_first = LedgerV2::Ticket.count

        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        LedgerV2::DailyRunner.call(run: run2, dry_run: false)

        expect(LedgerV2::Ticket.count).to eq(tickets_after_first)
      end
    end

    it "2回目の DailyRunner 実行で duplicate_prevented_count が記録される" do
      travel_to(base_day) do
        run1 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        LedgerV2::DailyRunner.call(run: run1, dry_run: false)

        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        result = LedgerV2::DailyRunner.call(run: run2, dry_run: false)

        expect(result.duplicate_prevented_count).to be_positive
      end
    end

    it "同じ canonical_key の Ticket は active なものが 1件のみ存在する" do
      # Day 0 を 2回実行
      run_daily_on(0)
      travel_to(base_day) do
        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        LedgerV2::DailyRunner.call(run: run2, dry_run: false)
      end

      tickets = LedgerV2::Ticket.where(metric_name: "ai_sns_posts_count",
                                       period_bucket: "daily:#{base_day.strftime('%Y-%m-%d')}")
      expect(tickets.count).to eq(1)
    end
  end

  # -----------------------------------------------------------------------
  # MVP 条件 11: StopCondition で Runner を止められる
  # -----------------------------------------------------------------------
  describe "MVP 11: StopCondition で Runner を止められる" do
    it "active な StopCondition があると Run が blocked になる" do
      LedgerV2::StopCondition.create!(
        target_type: "runner",
        target_name: "DailyRunner",
        severity:    "high",
        reason:      "テスト用緊急停止",
        created_by:  "test_human"
      )

      run = run_daily_on(0)
      expect(run.status).to eq("blocked")
    end

    it "blocked Run には skipped_reason が記録される" do
      LedgerV2::StopCondition.create!(
        target_type: "runner",
        target_name: "DailyRunner",
        severity:    "high",
        reason:      "緊急停止テスト",
        created_by:  "test_human"
      )

      run = run_daily_on(0)
      expect(run.skipped_reason).to eq("緊急停止テスト")
    end

    it "StopCondition を resolve! すると次回 Run が success になる" do
      stop = LedgerV2::StopCondition.create!(
        target_type: "runner",
        target_name: "DailyRunner",
        severity:    "high",
        reason:      "テスト緊急停止",
        created_by:  "test_human"
      )

      blocked_run = run_daily_on(0)
      expect(blocked_run.status).to eq("blocked")

      stop.resolve!(resolved_by: "test_human")

      ok_run = run_daily_on(1)
      expect(ok_run.status).to eq("success")
    end

    it "target_type: all の StopCondition は WeeklyRunner も止める" do
      LedgerV2::StopCondition.create!(
        target_type: "all",
        severity:    "critical",
        reason:      "全体停止テスト",
        created_by:  "test_human"
      )

      weekly_run = run_weekly_on(0)
      expect(weekly_run.status).to eq("blocked")
    end
  end

  # -----------------------------------------------------------------------
  # MVP 条件 12: dry_run ができる
  # -----------------------------------------------------------------------
  describe "MVP 12: dry_run ができる" do
    it "dry_run=true で DailyRunner を実行しても Ticket は作られない" do
      expect {
        run_daily_on(0, dry_run: true)
      }.not_to change(LedgerV2::Ticket, :count)
    end

    it "dry_run=true で DailyRunner を実行しても ticket_opened Event は作られない" do
      run_daily_on(0, dry_run: true)
      expect(LedgerV2::Event.where(event_type: "ticket_opened").count).to eq(0)
    end

    it "dry_run=true でも Run 自体は記録される（dry_run フラグ付き）" do
      expect {
        run_daily_on(0, dry_run: true)
      }.to change(LedgerV2::Run, :count).by(1)

      run = LedgerV2::Run.last
      expect(run.dry_run).to be true
      expect(run.status).to eq("success")
    end

    it "dry_run=true で WeeklyRunner を実行しても Artifact は作られない" do
      expect {
        run_weekly_on(0, dry_run: true)
      }.not_to change(LedgerV2::Artifact, :count)
    end

    it "dry_run=true で WeeklyRunner を実行しても artifact_created Event は作られない" do
      run_weekly_on(0, dry_run: true)
      expect(LedgerV2::Event.where(event_type: "artifact_created").count).to eq(0)
    end

    it "dry_run=true でも MetricSnapshot は保存される（観測ファクトは残す）" do
      expect {
        run_daily_on(0, dry_run: true)
      }.to change(LedgerV2::MetricSnapshot, :count).by(9)
    end
  end

  # -----------------------------------------------------------------------
  # MVP 条件 14: HealthSnapshot で価値を測れる
  # -----------------------------------------------------------------------
  describe "MVP 14: HealthSnapshot で価値を測れる" do
    before do
      7.times { |i| run_daily_on(i) }
      run_weekly_on(7)
    end

    # シミュレーションは base_day〜base_day+7日 で実行済み。
    # HealthSnapshot を計算する基準時刻は base_day + 8.days（全 Ticket の created_at より後）。
    # unresolved_ticket_age_avg は (measured_at - ticket.created_at) を使うため
    # measured_at > 全 Ticket の created_at でなければ負値になってしまう。
    let(:snapshot_at) { base_day + 8.days }

    it "CalculateHealthSnapshot.call が正常に動作して保存される" do
      snapshot = LedgerV2::CalculateHealthSnapshot.call(period: :daily, measured_at: snapshot_at)
      expect(snapshot).to be_persisted
    end

    it "weekly HealthSnapshot が 0〜1 の ticket_noise_rate を返す" do
      snapshot = LedgerV2::CalculateHealthSnapshot.call(
        period:      :weekly,
        measured_at: snapshot_at
      )
      expect(snapshot.ticket_noise_rate).to be_between(0.0, 1.0)
    end

    it "duplicate_prevented_count が集計される（重複防止の価値指標）" do
      # Day 1 を再度実行（before ブロックで 1回目は実行済み）→ 重複防止が発生する
      # snapshot_at の weekly window = base_day+1.day〜base_day+8.days に Day 1 が含まれる
      travel_to(base_day + 1.day) do
        LedgerV2::RunExecutor.call("daily_runner", idempotency_key: "dup_health_extra")
      end

      snapshot = LedgerV2::CalculateHealthSnapshot.call(
        period:      :weekly,
        measured_at: snapshot_at
      )
      expect(snapshot.duplicate_prevented_count).to be_positive
    end

    it "pending_review_count に weekly Artifact が計上される" do
      snapshot = LedgerV2::CalculateHealthSnapshot.call(period: :daily, measured_at: snapshot_at)
      expect(snapshot.pending_review_count).to be >= 1
    end

    it "dry_run=true の場合は DB に保存されない" do
      expect {
        LedgerV2::CalculateHealthSnapshot.call(period: :daily, dry_run: true)
      }.not_to change(LedgerV2::HealthSnapshot, :count)
    end
  end
end
