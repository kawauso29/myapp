class Admin::Ops::StopsController < Admin::Ops::BaseController
  # Phase 33 / 補強7: 停止台帳の閲覧 + 手動 lift アクション。
  # lift は監査証跡を残すため `lifted_by` / `lift_reason` 必須。
  def index
    @trigger_type = params[:trigger_type].presence
    @status = params[:status].presence
    @service_id = params[:service_id].presence

    scope = StopLedger.order(started_at: :desc, id: :desc)
    scope = scope.where(trigger_type: StopLedger.trigger_types[@trigger_type]) if @trigger_type.present? && StopLedger.trigger_types.key?(@trigger_type)
    scope = scope.where(status: StopLedger.statuses[@status]) if @status.present? && StopLedger.statuses.key?(@status)
    scope = scope.where(service_id: @service_id) if @service_id.present?

    @stops = scope.limit(100)
    @active_count = StopLedger.status_active.count
    @trigger_counts = StopLedger.group(:trigger_type).count.transform_keys { |k| StopLedger.trigger_types.key(k) || k }
  end

  def lift
    stop = StopLedger.find(params[:id])
    lift_reason = params[:lift_reason].to_s.strip
    lifted_by = params[:lifted_by].to_s.strip.presence || current_admin_actor

    if lift_reason.blank?
      redirect_to admin_ops_stops_path, alert: "lift_reason は必須です。"
      return
    end

    if stop.status_active?
      stop.lift!(by: lifted_by, reason: lift_reason)
      redirect_to admin_ops_stops_path, notice: "停止 ##{stop.id} を解除しました（by: #{lifted_by}）"
    else
      redirect_to admin_ops_stops_path, alert: "停止 ##{stop.id} は active ではないため解除できません（現在: #{stop.status}）"
    end
  end

  private

  def current_admin_actor
    return current_admin.email if respond_to?(:current_admin) && current_admin.respond_to?(:email)

    "admin_ui"
  end
end
