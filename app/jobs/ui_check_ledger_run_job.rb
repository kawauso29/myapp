class UiCheckLedgerRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # Phase 42 / UI伴走管理: AI SNS UI チェック会議を 2 日ごとに実行する。
  # MeetingLedger(ui_check) を生成することで stale_ui_check 検知を解消する。
  def perform
    self.class.with_job_idempotency("ui_check:#{Ledgers::TimeAxis.slot_token(:quarterly)}") do
      meeting = Ledgers::UiCheckRunner.call
      payload = JSON.parse(Ledgers::RunOutputFormatter.format(meeting:, operation: "ui_check"))
      Ledgers::SlackNotifier.notify(payload)
      meeting
    end
  end
end
