class Ops::LedgersController < Ops::BaseController
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
  end
end
