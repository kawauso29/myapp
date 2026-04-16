class AnnualPlanLedgerRunJob < ApplicationJob
  queue_as :default

  def perform
    Ledgers::AnnualPlanRunner.call
  end
end
