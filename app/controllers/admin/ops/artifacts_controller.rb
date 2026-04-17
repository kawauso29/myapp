class Admin::Ops::ArtifactsController < Admin::Ops::BaseController
  # Phase 31b: 成果物台帳のリードオンリー閲覧。
  def index
    @artifact_type = params[:artifact_type].presence
    @service_id = params[:service_id].presence

    scope = ArtifactLedger.order(published_at: :desc, id: :desc)
    scope = scope.where(artifact_type: ArtifactLedger.artifact_types[@artifact_type]) if @artifact_type.present?
    scope = scope.where(service_id: @service_id) if @service_id.present?
    @artifacts = scope.limit(100)

    scope_stops = StopLedger.order(started_at: :desc, id: :desc)
    scope_stops = scope_stops.where(service_id: @service_id) if @service_id.present?
    @active_stops = scope_stops.status_active.limit(20)
    @recent_stops = scope_stops.limit(20)

    scope_feedback = CustomerFeedbackLedger.order(received_at: :desc, id: :desc)
    scope_feedback = scope_feedback.where(service_id: @service_id) if @service_id.present?
    @recent_feedback = scope_feedback.limit(20)
  end
end
