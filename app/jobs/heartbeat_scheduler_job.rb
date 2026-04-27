# Phase 44b / §12: heartbeat `next_run_at` 駆動のジョブスケジューラ。
#
# `ServiceHeartbeat` の `next_run_at` が現在時刻以前のレコードを検出し、
# 対応する `ServiceScheduleDefinition` のジョブを起動する。
# ジョブ実行後は `next_run_at` を次の interval 分だけ進める。
#
# recurring.yml で 5 分毎に起動し、cron ベースの直接スケジューリングを補完する。
class HeartbeatSchedulerJob < ApplicationJob
  queue_as :default

  # @param dry_run [Boolean] true の場合、ジョブは enqueue せず対象の heartbeat 数のみ返す
  def perform(dry_run: false)
    due_heartbeats = ServiceHeartbeat
                       .where(status: :active)
                       .where("next_run_at <= ?", Time.current)

    scheduled_count = 0
    error_count = 0

    due_heartbeats.find_each do |heartbeat|
      begin
        schedule = find_schedule_for(heartbeat)
        next unless schedule

        unless dry_run
          enqueue_job(schedule, heartbeat)
          advance_next_run!(heartbeat)
        end

        scheduled_count += 1
      rescue StandardError => e
        error_count += 1
        Rails.logger.error("[HeartbeatScheduler] error processing heartbeat=#{heartbeat.id}: #{e.class}: #{e.message}")
      end
    end

    Rails.logger.info("[HeartbeatScheduler] scheduled=#{scheduled_count} errors=#{error_count} dry_run=#{dry_run}")
    scheduled_count
  end

  private

  # heartbeat に紐づく ServiceScheduleDefinition を検索する。
  # meeting_definition の meeting_key + service_id から job_key を推定する。
  def find_schedule_for(heartbeat)
    meeting_def = heartbeat.meeting_definition
    return nil unless meeting_def

    # job_key の命名規則: "<meeting_key>_ledger_run" or "<meeting_key>_ledger_run:<service_id>"
    base_key = "#{meeting_def.meeting_key}_ledger_run"
    candidates = if heartbeat.service_id.present?
      ["#{base_key}:#{heartbeat.service_id}", base_key]
    else
      [base_key]
    end

    ServiceScheduleDefinition.active.find_by(job_key: candidates)
  end

  def enqueue_job(schedule, heartbeat)
    klass = schedule.job_klass
    unless klass
      Rails.logger.warn("[HeartbeatScheduler] unknown job_class=#{schedule.job_class} for job_key=#{schedule.job_key}")
      return
    end

    args = Array(schedule.args)
    klass.perform_later(*args)
    Rails.logger.info("[HeartbeatScheduler] enqueued #{schedule.job_class} args=#{args} heartbeat=#{heartbeat.id}")
  rescue StandardError => e
    Rails.logger.error("[HeartbeatScheduler] failed to enqueue #{schedule.job_class}: #{e.message}")
  end

  def advance_next_run!(heartbeat)
    interval = Ledgers::TimeAxis.interval_for(
      heartbeat.due_cycle,
      service_id: heartbeat.service_id
    )
    heartbeat.update!(
      next_run_at: Time.current + interval,
      last_run_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("[HeartbeatScheduler] failed to advance heartbeat=#{heartbeat.id}: #{e.message}")
  end
end
