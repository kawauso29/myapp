class AnnualPlanLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  def perform
    self.class.with_job_idempotency("annual_plan:#{Ledgers::TimeAxis.slot_token(:annual)}") do
      meeting = Ledgers::AnnualPlanRunner.call
      payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "annual_plan"))
      Ledgers::SlackNotifier.notify(payload)
      meeting
    end
  end
end
