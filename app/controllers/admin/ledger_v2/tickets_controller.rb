class Admin::LedgerV2::TicketsController < Admin::LedgerV2::BaseController
  # Ticket 14: Ticket Review UI
  # 人間が Ticket を accept / reject / defer / reopen できる画面。
  # 運用ルール §7: Artifact は人間レビュー必須（Ticket も同様）。
  # 運用ルール §8: StopCondition 解除は人間のみ。ここでは Ticket の状態変更を担う。

  VALID_REVIEW_ACTIONS = %w[accept reject defer reopen].freeze

  def index
    scope = ::LedgerV2::Ticket.order(created_at: :desc)

    scope = scope.where(status: filtered_status) if filtered_status.present?
    scope = scope.where(severity: filtered_severity) if filtered_severity.present?

    @tickets = scope.limit(50)
    @filter_status   = filtered_status
    @filter_severity = filtered_severity
  end

  # PATCH /admin/ledger_v2/tickets/:id
  # params[:review_action] は "accept" / "reject" / "defer" / "reopen" のいずれか。
  def update
    @ticket = ::LedgerV2::Ticket.find(params[:id])
    action  = params[:review_action].to_s

    unless VALID_REVIEW_ACTIONS.include?(action)
      return redirect_to admin_ledger_v2_tickets_path, alert: "不正な操作です: #{action}"
    end

    apply_review_action(@ticket, action)
  end

  private

  def apply_review_action(ticket, action)
    case action
    when "accept"
      ticket.update!(
        human_decision: :accepted,
        review_status:  :accepted
      )
      redirect_to admin_ledger_v2_tickets_path, notice: "Ticket ##{ticket.id} を accept しました。"
    when "reject"
      ticket.update!(
        human_decision:  :rejected,
        status:          :rejected,
        review_status:   :review_rejected,
        rejected_reason: params[:rejected_reason].presence,
        resolved_at:     Time.current
      )
      redirect_to admin_ledger_v2_tickets_path, notice: "Ticket ##{ticket.id} を reject しました。"
    when "defer"
      ticket.update!(
        human_decision: :deferred,
        status:         :deferred,
        review_status:  :review_deferred
      )
      redirect_to admin_ledger_v2_tickets_path, notice: "Ticket ##{ticket.id} を defer しました。"
    when "reopen"
      ticket.update!(
        human_decision: :none,
        status:         :open,
        review_status:  :pending,
        rejected_reason: nil,
        resolved_at:    nil
      )
      redirect_to admin_ledger_v2_tickets_path, notice: "Ticket ##{ticket.id} を reopen しました。"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_ledger_v2_tickets_path, alert: "更新に失敗しました: #{e.message}"
  end

  def filtered_status
    params[:status].presence
  end

  def filtered_severity
    params[:severity].presence
  end
end
