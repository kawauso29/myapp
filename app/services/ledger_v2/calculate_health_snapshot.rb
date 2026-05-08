# LedgerV2::CalculateHealthSnapshot — Ledger V2 の健全性指標を集計するサービス。
#
# 責務:
# - 指定期間のデータから各健全性指標を計算して HealthSnapshot を保存する
# - 集計のみを行い、Ticket 作成・Alert 送信などの副作用は起こさない
# - 既存スナップショット（同一 period / measured_at）は upsert で上書きする
#
# 重要ルール:
# - 採用率(artifact_acceptance_rate)とノイズ率(ticket_noise_rate)を最重要視する
# - kpi_improvement_after_ticket_rate は初期実装では「resolved Ticket の割合」で近似する
# - dry_run: true の場合は DB に書き込まずに結果を返す
#
# 呼び出し例:
#   LedgerV2::CalculateHealthSnapshot.call(period: :daily)
#   LedgerV2::CalculateHealthSnapshot.call(period: :weekly, measured_at: 1.week.ago, dry_run: true)
#
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::CalculateHealthSnapshot」
module LedgerV2
  module CalculateHealthSnapshot
    # @param period [Symbol]  :daily または :weekly
    # @param measured_at [Time]  集計基準時点（デフォルト: 現在時刻）
    # @param dry_run [Boolean]  true の場合は DB に書き込まない
    # @return [LedgerV2::HealthSnapshot]  集計結果（dry_run 時は未保存インスタンス）
    def self.call(period:, measured_at: Time.current, dry_run: false)
      window_start = period_window_start(period, measured_at)

      # 各指標を計算する
      ticket_noise         = calculate_ticket_noise_rate(window_start, measured_at)
      artifact_acceptance  = calculate_artifact_acceptance_rate(window_start, measured_at)
      runner_failure       = calculate_runner_failure_rate(window_start, measured_at)
      unresolved_age_avg   = calculate_unresolved_ticket_age_avg(measured_at)
      human_intervention   = calculate_human_intervention_rate(window_start, measured_at)
      kpi_improvement      = calculate_kpi_improvement_rate(window_start, measured_at)
      stop_triggers        = count_stop_triggers(window_start, measured_at)
      duplicates_prevented = sum_duplicate_prevented(window_start, measured_at)
      pending_reviews      = count_pending_reviews
      open_tickets         = count_open_tickets
      draft_pr_metrics     = calculate_draft_pr_metrics(window_start, measured_at)

      attrs = {
        period:                              period,
        measured_at:                         measured_at,
        ticket_noise_rate:                   ticket_noise,
        artifact_acceptance_rate:            artifact_acceptance,
        runner_failure_rate:                 runner_failure,
        unresolved_ticket_age_avg:           unresolved_age_avg,
        human_intervention_rate:             human_intervention,
        kpi_improvement_after_ticket_rate:   kpi_improvement,
        stop_trigger_count:                  stop_triggers,
        duplicate_prevented_count:           duplicates_prevented,
        pending_review_count:                pending_reviews,
        open_ticket_count:                   open_tickets,
        metadata_json: {
          "window_start" => window_start.iso8601,
          "window_end"   => measured_at.iso8601,
          "dry_run"      => dry_run,
          "draft_pr_metrics" => draft_pr_metrics
        }
      }

      snapshot = HealthSnapshot.new(attrs)
      snapshot.save! unless dry_run
      snapshot
    end

    # --- 指標計算メソッド群（private） ---

    # ticket_noise_rate: 期間内に作成された Ticket のうち rejected / duplicate の割合
    def self.calculate_ticket_noise_rate(window_start, window_end)
      scope = LedgerV2::Ticket.where(created_at: window_start..window_end)
      total = scope.count
      return 0.0 if total.zero?

      noise = scope.where(status: [
        LedgerV2::Ticket.statuses[:rejected],
        LedgerV2::Ticket.statuses[:duplicate]
      ]).count
      (noise.to_f / total).round(4)
    end
    private_class_method :calculate_ticket_noise_rate

    # artifact_acceptance_rate: 期間内の最終判定済み Artifact（draft / pending 除く）のうち accepted / published の割合。
    #
    # draft  : 未完成のためそもそも対象外
    # pending: レビュー待ち（未決）のため分母に含めない。pending が多くても採用率を不当に下げない。
    # 対象: accepted / published / review_rejected / review_deferred / needs_more_info
    # 期間内に最終判定済み Artifact が 0 件の場合は全期間の採用率にフォールバックする。
    def self.calculate_artifact_acceptance_rate(window_start, window_end)
      decided_statuses = [
        LedgerV2::Artifact.review_statuses[:accepted],
        LedgerV2::Artifact.review_statuses[:published],
        LedgerV2::Artifact.review_statuses[:review_rejected],
        LedgerV2::Artifact.review_statuses[:review_deferred],
        LedgerV2::Artifact.review_statuses[:needs_more_info]
      ]
      scope = LedgerV2::Artifact.where(created_at: window_start..window_end)
                                .where(review_status: decided_statuses)
      total = scope.count

      if total.zero?
        # ウィンドウ内にデータなし → 全期間の採用率で代替する
        return calculate_alltime_artifact_acceptance_rate
      end

      accepted = scope.where(review_status: [
        LedgerV2::Artifact.review_statuses[:accepted],
        LedgerV2::Artifact.review_statuses[:published]
      ]).count
      (accepted.to_f / total).round(4)
    end

    # artifact_acceptance_rate の全期間集計（ウィンドウ内が空のときのフォールバック）
    # draft / pending を除いた最終判定済み Artifact で採用率を計算する。
    def self.calculate_alltime_artifact_acceptance_rate
      decided_statuses = [
        LedgerV2::Artifact.review_statuses[:accepted],
        LedgerV2::Artifact.review_statuses[:published],
        LedgerV2::Artifact.review_statuses[:review_rejected],
        LedgerV2::Artifact.review_statuses[:review_deferred],
        LedgerV2::Artifact.review_statuses[:needs_more_info]
      ]
      all_scope = LedgerV2::Artifact.where(review_status: decided_statuses)
      total = all_scope.count
      return 0.0 if total.zero?

      accepted = all_scope.where(review_status: [
        LedgerV2::Artifact.review_statuses[:accepted],
        LedgerV2::Artifact.review_statuses[:published]
      ]).count
      (accepted.to_f / total).round(4)
    end
    private_class_method :calculate_artifact_acceptance_rate
    private_class_method :calculate_alltime_artifact_acceptance_rate

    # runner_failure_rate: 期間内の Run のうち failed の割合
    def self.calculate_runner_failure_rate(window_start, window_end)
      scope = LedgerV2::Run.where(started_at: window_start..window_end)
      total = scope.count
      return 0.0 if total.zero?

      failed = scope.where(status: LedgerV2::Run.statuses[:failed]).count
      (failed.to_f / total).round(4)
    end
    private_class_method :calculate_runner_failure_rate

    # unresolved_ticket_age_avg: 現在アクティブな Ticket の作成〜現在の平均経過時間（時間単位）
    def self.calculate_unresolved_ticket_age_avg(measured_at)
      active_tickets = LedgerV2::Ticket.active
      return 0.0 if active_tickets.empty?

      total_hours = active_tickets.sum { |t| (measured_at - t.created_at) / 3600.0 }
      (total_hours / active_tickets.count).round(2)
    end
    private_class_method :calculate_unresolved_ticket_age_avg

    # human_intervention_rate: 期間内に人間が手動判断（rejected / deferred / edited）した Ticket の割合
    def self.calculate_human_intervention_rate(window_start, window_end)
      scope = LedgerV2::Ticket.where(created_at: window_start..window_end)
      total = scope.count
      return 0.0 if total.zero?

      intervened = scope.where(human_decision: [
        LedgerV2::Ticket.human_decisions[:rejected],
        LedgerV2::Ticket.human_decisions[:deferred],
        LedgerV2::Ticket.human_decisions[:edited]
      ]).count
      (intervened.to_f / total).round(4)
    end
    private_class_method :calculate_human_intervention_rate

    # kpi_improvement_after_ticket_rate: 期間内に resolved になった Ticket の割合（KPI 改善の近似）
    def self.calculate_kpi_improvement_rate(window_start, window_end)
      scope = LedgerV2::Ticket.where(created_at: window_start..window_end)
      total = scope.count
      return 0.0 if total.zero?

      resolved = scope.where(status: LedgerV2::Ticket.statuses[:resolved]).count
      (resolved.to_f / total).round(4)
    end
    private_class_method :calculate_kpi_improvement_rate

    # stop_trigger_count: 期間内に有効化された StopCondition の件数
    def self.count_stop_triggers(window_start, window_end)
      LedgerV2::StopCondition.where(created_at: window_start..window_end).count
    end
    private_class_method :count_stop_triggers

    # duplicate_prevented_count: 期間内の Run が記録した重複防止件数の合計
    def self.sum_duplicate_prevented(window_start, window_end)
      LedgerV2::Run.where(started_at: window_start..window_end)
                   .sum(:duplicate_prevented_count)
    end
    private_class_method :sum_duplicate_prevented

    # pending_review_count: レビュー待ちの Artifact + Ticket の合計
    def self.count_pending_reviews
      artifact_pending = LedgerV2::Artifact.awaiting_review.count
      ticket_pending   = LedgerV2::Ticket.where(
        review_status: LedgerV2::Ticket.review_statuses[:pending]
      ).count
      artifact_pending + ticket_pending
    end
    private_class_method :count_pending_reviews

    # open_ticket_count: 現在アクティブな Ticket 件数
    def self.count_open_tickets
      LedgerV2::Ticket.active.count
    end
    private_class_method :count_open_tickets

    # draft_pr_metrics: Artifact 承認後の draft PR 連動が健全に動いているかを見る補助指標。
    def self.calculate_draft_pr_metrics(window_start, window_end)
      success_count = LedgerV2::Event.where(event_type: "draft_pr_created", occurred_at: window_start..window_end).count
      failure_count = LedgerV2::Event.where(event_type: "draft_pr_create_failed", occurred_at: window_start..window_end).count
      total_attempts = success_count + failure_count

      pr_artifacts = LedgerV2::Artifact
                       .where(artifact_type: "ci_fix_suggestion")
                       .where("metadata_json ? :key", key: "draft_pr")
      rejected_count = pr_artifacts.where(review_status: LedgerV2::Artifact.review_statuses[:review_rejected]).count
      total_pr_artifacts = pr_artifacts.count

      {
        "creation_success_rate" => total_attempts.zero? ? 0.0 : (success_count.to_f / total_attempts).round(4),
        "created_count" => success_count,
        "failed_count" => failure_count,
        "draft_pr_artifact_rejection_rate" => total_pr_artifacts.zero? ? 0.0 : (rejected_count.to_f / total_pr_artifacts).round(4),
        "ci_repass_rate" => nil
      }
    end
    private_class_method :calculate_draft_pr_metrics

    # 集計ウィンドウの開始時刻を返す
    def self.period_window_start(period, measured_at)
      case period.to_sym
      when :daily  then measured_at - 1.day
      when :weekly then measured_at - 1.week
      else raise ArgumentError, "unknown period: #{period}"
      end
    end
    private_class_method :period_window_start
  end
end
