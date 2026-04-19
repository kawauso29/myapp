class QuarterlyReviewLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  def perform
    self.class.with_job_idempotency("quarterly_review:#{Ledgers::TimeAxis.slot_token(:quarterly)}") do
      meeting = Ledgers::QuarterlyReviewRunner.call
      payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "quarterly_review"))
      Ledgers::SlackNotifier.notify(payload)
      meeting
    end
  end
end
