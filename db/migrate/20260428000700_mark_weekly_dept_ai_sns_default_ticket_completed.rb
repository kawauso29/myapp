class MarkWeeklyDeptAiSnsDefaultTicketCompleted < ActiveRecord::Migration[8.1]
  TITLE = "weekly_dept default ticket for ai_sns".freeze

  def up
    ticket = TicketLedger
               .where("LOWER(title) = LOWER(?)", TITLE)
               .where(service_id: "ai_sns", due_cycle: "weekly", ticket_type: "operations")
               .where.not(status: %w[completed cancelled])
               .first
    return unless ticket

    ticket.update_columns(
      status: TicketLedger.statuses[:completed],
      resolved_at: Time.current
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
