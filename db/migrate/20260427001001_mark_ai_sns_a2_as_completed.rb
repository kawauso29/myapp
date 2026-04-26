class MarkAiSnsA2AsCompleted < ActiveRecord::Migration[8.1]
  def up
    ticket = TicketLedger.find_by(idempotency_key: "ai_sns_plan:A2")
    return unless ticket

    ticket.update!(status: :completed, due_date: Date.current) unless ticket.status_completed?
  end

  def down
    # irreversible data migration
  end
end
