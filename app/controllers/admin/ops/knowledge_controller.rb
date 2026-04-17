class Admin::Ops::KnowledgeController < Admin::Ops::BaseController
  # Phase 37 / §20: 知識台帳（ADR / Runbook / Incident / Deploy）のリードオンリー閲覧。
  def index
    @kind = params[:kind].presence
    @status = params[:status].presence

    scope = KnowledgeLedger.order(created_at: :desc, id: :desc)
    scope = scope.where(kind: KnowledgeLedger.kinds[@kind]) if @kind.present? && KnowledgeLedger.kinds.key?(@kind)
    scope = scope.where(status: KnowledgeLedger.statuses[@status]) if @status.present? && KnowledgeLedger.statuses.key?(@status)

    @records = scope.limit(100)
    @kind_counts = KnowledgeLedger.group(:kind).count.transform_keys { |k| KnowledgeLedger.kinds.key(k) || k }
    @status_counts = KnowledgeLedger.group(:status).count.transform_keys { |k| KnowledgeLedger.statuses.key(k) || k }
  end
end
