class Admin::Ops::AuditDecisionsController < Admin::Ops::BaseController
  # Phase 32 / §18: 監査判断台帳のリードオンリー閲覧。
  # reason_code の分布を可視化し、approve 以外（reject / request_changes / abstain）を目立たせる。
  def index
    @decision = params[:decision].presence
    @service_id = params[:service_id].presence

    scope = AuditDecisionLedger.order(decided_at: :desc, id: :desc)
    scope = scope.where(decision: AuditDecisionLedger.decisions[@decision]) if @decision.present? && AuditDecisionLedger.decisions.key?(@decision)
    scope = scope.where(service_id: @service_id) if @service_id.present?

    @decisions = scope.limit(100)
    @reason_code_counts = scope.reorder(nil).group(:reason_code).count
    @decision_counts = scope.reorder(nil).group(:decision).count.transform_keys { |k| AuditDecisionLedger.decisions.key(k) || k }
    @non_approval_recent = AuditDecisionLedger.non_approvals.order(decided_at: :desc).limit(10)
  end
end
