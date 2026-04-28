# LedgerV2::WeeklyRunner — 週次レビュー・Artifact draft を作る。
#
# 責務:
# - open / deferred Ticket を集める
# - 直近 7 日の MetricSnapshot を収集する
# - BuildWeeklyArtifact で週次レビュー Artifact 本文を生成する
# - Artifact を pending（人間レビュー待ち）で保存する
# - artifact_created Event を記録する
# - RunnerResult を返す
#
# やらないこと:
# - 戦略を確定しない
# - Ticket を大量に新規作成しない
# - 自動 PR を作らない
# - 自動マージしない
# - Monthly / Quarterly へ勝手に昇格しない
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::WeeklyRunner」
module LedgerV2
  class WeeklyRunner
    WEEKLY_PERIOD_DAYS = 7

    # @param run      [LedgerV2::Run]  RunExecutor が生成した Run
    # @param dry_run  [Boolean]        true なら DB 書き込みをスキップ
    # @return [LedgerV2::RunExecutor::RunnerResult]
    def self.call(run:, dry_run: false, **)
      new(run: run, dry_run: dry_run).call
    end

    def initialize(run:, dry_run:)
      @run     = run
      @dry_run = dry_run
    end

    def call
      open_tickets      = collect_open_tickets
      metric_snapshots  = collect_metric_snapshots
      previous_artifacts = collect_previous_artifacts

      artifact_body = BuildWeeklyArtifact.call(
        run:                       @run,
        open_tickets:              open_tickets,
        metric_snapshots:          metric_snapshots,
        previous_weekly_artifacts: previous_artifacts
      )

      created_artifact_count = 0
      created_event_count    = 0
      updated_ticket_count   = 0

      unless @dry_run
        artifact = Artifact.create!(
          artifact_type: "weekly_review",
          title:         "週次レビュー #{Time.current.strftime('%Y-%m-%d')}",
          body:          artifact_body,
          format:        "markdown",
          review_status: :pending,
          run:           @run
        )
        created_artifact_count += 1

        Event.create!(
          run:        @run,
          event_type: "artifact_created",
          severity:   :info,
          occurred_at: Time.current,
          message:    "週次レビュー Artifact ##{artifact.id} を作成しました",
          payload_json: {
            artifact_id:    artifact.id,
            open_ticket_count: open_tickets.size
          }
        )
        created_event_count += 1
      end

      RunExecutor::RunnerResult.new(
        created_artifact_count: created_artifact_count,
        created_event_count:    created_event_count,
        updated_ticket_count:   updated_ticket_count
      )
    end

    private

    def collect_open_tickets
      Ticket.active.order(created_at: :asc)
    rescue => e
      Rails.logger.warn("[LedgerV2::WeeklyRunner] collect_open_tickets failed: #{e.message}")
      []
    end

    def collect_metric_snapshots
      since = Time.current - WEEKLY_PERIOD_DAYS.days
      MetricSnapshot.where("measured_at >= ?", since).order(measured_at: :asc)
    rescue => e
      Rails.logger.warn("[LedgerV2::WeeklyRunner] collect_metric_snapshots failed: #{e.message}")
      []
    end

    def collect_previous_artifacts
      Artifact.where(artifact_type: "weekly_review")
               .order(created_at: :desc)
               .limit(4)
    rescue => e
      Rails.logger.warn("[LedgerV2::WeeklyRunner] collect_previous_artifacts failed: #{e.message}")
      []
    end
  end
end
