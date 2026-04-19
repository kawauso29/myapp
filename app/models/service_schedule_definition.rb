# Phase 44c / §12: recurring.yml のジョブ定義を DB 化。
#
# `job_key` がユニークキー。enabled なレコードのみスケジューラが対象とする。
# `HeartbeatSchedulerJob` がこのテーブルと `ServiceHeartbeat` を統合して
# 動的にジョブをスケジュールする。
class ServiceScheduleDefinition < ApplicationRecord
  CADENCES = {
    daily: 0,
    weekly: 1,
    monthly: 2,
    quarterly: 3,
    annual: 4,
    long_term: 5
  }.freeze

  enum :cadence, CADENCES, prefix: true

  validates :job_key, :job_class, :cron, presence: true
  validates :job_key, uniqueness: true
  validates :job_class, format: { with: /\A[A-Z][A-Za-z0-9:]+\z/, message: "must be a valid Ruby class name" }
  validate :cron_format_valid

  scope :active, -> { where(enabled: true) }

  # ジョブクラスを定数化して返す。存在しない場合は nil。
  def job_klass
    job_class.constantize
  rescue NameError
    nil
  end

  private

  def cron_format_valid
    return if cron.blank?

    parts = cron.strip.split
    return if parts.length == 5 # 標準 cron: min hour day month weekday

    errors.add(:cron, "must be a valid 5-field cron expression")
  end
end
