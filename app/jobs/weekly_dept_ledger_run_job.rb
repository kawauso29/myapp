class WeeklyDeptLedgerRunJob < ApplicationJob
  queue_as :default

  def perform(service_id = nil, ticket_inputs: nil, **options)
    resolved_service_id = options[:service_id] || options["service_id"] || service_id || "ai_sns"
    resolved_ticket_inputs = options[:ticket_inputs] || options["ticket_inputs"] || ticket_inputs

    meeting = Ledgers::WeeklyDeptRunner.call(service_id: resolved_service_id, ticket_inputs: resolved_ticket_inputs)
    payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "weekly_dept"))
    Ledgers::SlackNotifier.notify(payload)
    meeting
  end
end
