class MonthlyOpsLedgerRunJob < ApplicationJob
  queue_as :default

  def perform(resolution_map: {})
    meeting = Ledgers::MonthlyOpsRunner.call(resolution_map:)
    payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "monthly_ops"))
    Ledgers::SlackNotifier.notify(payload)
    meeting
  end
end
