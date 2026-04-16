class QuarterlyReviewLedgerRunJob < ApplicationJob
  queue_as :default

  def perform
    Ledgers::QuarterlyReviewRunner.call
  end
end
