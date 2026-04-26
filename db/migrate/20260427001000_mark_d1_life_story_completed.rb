class MarkD1LifeStoryCompleted < ActiveRecord::Migration[8.1]
  def up
    ticket = TicketLedger.find_ai_sns_plan_by_item_key("D1")
    return unless ticket

    ticket.update_columns(
      status: TicketLedger.statuses[:completed],
      due_date: Date.current
    )
  end

  def down
    ticket = TicketLedger.find_ai_sns_plan_by_item_key("D1")
    return unless ticket

    ticket.update_columns(status: TicketLedger.statuses[:executing])
  end
end
