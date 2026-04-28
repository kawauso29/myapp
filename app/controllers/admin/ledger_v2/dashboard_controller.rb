class Admin::LedgerV2::DashboardController < Admin::LedgerV2::BaseController
  # Ticket 13: Ledger V2 の状態を一目で把握するダッシュボード。
  # Run / Ticket / Artifact / StopCondition の集計値と直近レコードを表示する。
  def index
    # --- Run 集計 ---
    @recent_runs      = ::LedgerV2::Run.order(started_at: :desc).limit(10)
    @run_stats        = {
      total:   ::LedgerV2::Run.count,
      success: ::LedgerV2::Run.where(status: ::LedgerV2::Run.statuses[:success]).count,
      failed:  ::LedgerV2::Run.where(status: ::LedgerV2::Run.statuses[:failed]).count,
      blocked: ::LedgerV2::Run.where(status: ::LedgerV2::Run.statuses[:blocked]).count,
      dry_run: ::LedgerV2::Run.where(dry_run: true).count
    }

    # --- Ticket 集計 ---
    @open_tickets     = ::LedgerV2::Ticket.active.order(created_at: :desc).limit(10)
    @ticket_stats     = {
      open:        ::LedgerV2::Ticket.where(status: ::LedgerV2::Ticket.statuses[:open]).count,
      in_progress: ::LedgerV2::Ticket.where(status: ::LedgerV2::Ticket.statuses[:in_progress]).count,
      deferred:    ::LedgerV2::Ticket.where(status: ::LedgerV2::Ticket.statuses[:deferred]).count,
      total:       ::LedgerV2::Ticket.count
    }

    # --- Artifact 集計 ---
    @pending_artifacts = ::LedgerV2::Artifact.awaiting_review.order(created_at: :desc).limit(5)
    @artifact_stats    = {
      pending:  ::LedgerV2::Artifact.awaiting_review.count,
      accepted: ::LedgerV2::Artifact.where(review_status: ::LedgerV2::Artifact.review_statuses[:accepted]).count,
      total:    ::LedgerV2::Artifact.count
    }

    # --- StopCondition 集計 ---
    @active_stop_conditions = ::LedgerV2::StopCondition.active_conditions.order(created_at: :desc)
    @stop_condition_count   = @active_stop_conditions.count

    # --- duplicate_prevented 合計 ---
    @duplicate_prevented_total = ::LedgerV2::Run.sum(:duplicate_prevented_count)
  end
end
