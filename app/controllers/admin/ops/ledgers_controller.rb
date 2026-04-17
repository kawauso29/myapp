class Admin::Ops::LedgersController < Admin::Ops::BaseController
  def index
    @service_id = params[:service_id].presence
    @meeting_key = params[:meeting_key].presence

    meeting_scope = MeetingLedger.order(held_at: :desc, id: :desc)
    meeting_scope = meeting_scope.where(service_id: @service_id) if @service_id.present?
    meeting_scope = meeting_scope.where(meeting_key: @meeting_key) if @meeting_key.present?
    @meeting_ledgers = meeting_scope.limit(50)

    ticket_scope = TicketLedger.order(created_at: :desc, id: :desc)
    ticket_scope = ticket_scope.where(service_id: @service_id) if @service_id.present?
    if @meeting_key.present?
      ticket_scope = ticket_scope.joins(:source_meeting).where(meeting_ledgers: { meeting_key: @meeting_key })
    end
    @ticket_ledgers = ticket_scope.includes(:source_meeting).limit(100)
    @open_improvement_count = TicketLedger.ticket_type_improvement.status_waiting_review.count

    @alert_summary = build_alert_summary
    @service_summaries = build_service_summaries unless @service_id.present?
  end

  private

  def build_alert_summary
    {
      waiting_review: TicketLedger.ticket_type_improvement.status_waiting_review.count,
      overdue:        TicketLedger.status_overdue.count,
      non_approval:   AuditDecisionLedger.non_approvals.count,
      active_stop:    StopLedger.status_active.count
    }
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_alert_summary: #{e.message}")
    {}
  end

  def build_service_summaries
    services = %w[ai_sns trading picro]
    {
      meeting: MeetingLedger.where(service_id: services).group(:service_id).count,
      ticket:  TicketLedger.where(service_id: services).group(:service_id).count,
      stop:    StopLedger.status_active.where(service_id: services).group(:service_id).count
    }
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_service_summaries: #{e.message}")
    {}
  end
end
