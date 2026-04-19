class DailyLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # 設計書 §12.6 選択肢A: daily cadence（圧縮 30分周期）の自動出力。
  # KPI スナップショット・異常検知を MeetingLedger(daily) に記録する。
  def perform(service_id = "ai_sns")
    self.class.with_job_idempotency("daily:#{service_id}:#{Ledgers::TimeAxis.slot_token(:daily)}") do
      meeting = Ledgers::DailyRunner.call(service_id:)
      payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "daily"))
      Ledgers::SlackNotifier.notify(payload)
      meeting
    end
  end
end
