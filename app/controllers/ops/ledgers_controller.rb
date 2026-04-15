class Ops::LedgersController < Ops::BaseController
  def index
    @service_id = params[:service_id].presence
    @meeting_key = params[:meeting_key].presence

    @meeting_ledgers = MeetingLedger
      .order(held_at: :desc, id: :desc)
      .limit(50)
    @meeting_ledgers = @meeting_ledgers.where(service_id: @service_id) if @service_id.present?
    @meeting_ledgers = @meeting_ledgers.where(meeting_key: @meeting_key) if @meeting_key.present?

    @ticket_ledgers = TicketLedger
      .includes(:source_meeting)
      .order(created_at: :desc, id: :desc)
      .limit(100)
    @ticket_ledgers = @ticket_ledgers.where(service_id: @service_id) if @service_id.present?
    if @meeting_key.present?
      @ticket_ledgers = @ticket_ledgers.joins(:source_meeting).where(meeting_ledgers: { meeting_key: @meeting_key })
    end
  end
end
