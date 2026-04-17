class QuarterlyReviewLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  def perform
    quarter_number = ((Date.current.month - 1) / 3) + 1
    self.class.with_job_idempotency("quarterly_review:#{Date.current.year}:q#{quarter_number}") do
      Ledgers::QuarterlyReviewRunner.call
    end
  end
end
