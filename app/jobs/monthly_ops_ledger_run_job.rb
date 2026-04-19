class MonthlyOpsLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  def perform(resolution_map: {})
    self.class.with_job_idempotency("monthly_ops:#{Ledgers::TimeAxis.slot_token(:monthly)}") do
      meeting = Ledgers::MonthlyOpsRunner.call(resolution_map:)
      payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "monthly_ops"))
      Ledgers::SlackNotifier.notify(payload)
      meeting
    end
  end
end
