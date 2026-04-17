class AnnualPlanLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  def perform
    self.class.with_job_idempotency("annual_plan:fy#{Date.current.year}") do
      Ledgers::AnnualPlanRunner.call
    end
  end
end
