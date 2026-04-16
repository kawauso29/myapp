class TicketOverdueCheckJob < ApplicationJob
  queue_as :default

  def perform
    overdue_tickets = TicketLedger.overdue_candidates
    count = overdue_tickets.count
    overdue_tickets.find_each { |ticket| ticket.update!(status: :overdue) }
    Ledgers::SlackNotifier.notify(operation: "check_overdue", overdue_marked: count) if count.positive?
    Rails.logger.info("TicketOverdueCheckJob marked #{count} tickets as overdue")
    count
  end
end
