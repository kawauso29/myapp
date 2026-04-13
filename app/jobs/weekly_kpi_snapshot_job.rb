class WeeklyKpiSnapshotJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  def perform
    snap = KpiSnapshot.record_weekly!
    if snap
      Rails.logger.info("[WeeklyKpiSnapshotJob] KPI snapshot recorded for #{snap.recorded_on}")
    else
      Rails.logger.warn("[WeeklyKpiSnapshotJob] KPI snapshot recording failed")
    end
  end
end
