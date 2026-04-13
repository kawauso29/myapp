class KpiSnapshot < ApplicationRecord
  PERIODS = %w[daily weekly].freeze

  validates :period,      inclusion: { in: PERIODS }
  validates :recorded_on, presence: true, uniqueness: { scope: :period }
  validates :metrics,     presence: true

  scope :daily,  -> { where(period: "daily") }
  scope :weekly, -> { where(period: "weekly") }
  scope :recent, ->(n = 12) { order(recorded_on: :desc).limit(n) }

  # 週次 KPI を記録（当日分が既にあれば上書き）
  def self.record_weekly!
    metrics = Admin::KpiService.weekly_metrics
    snap = find_or_initialize_by(period: "weekly", recorded_on: Date.current)
    snap.update!(metrics: metrics)
    snap
  rescue => e
    Rails.logger.error("[KpiSnapshot.record_weekly!] failed: #{e.message}")
    nil
  end

  # 直近 n 週分を古い順に返し、前週比を含んだ配列を返す
  # [{ recorded_on:, metrics:, delta: { wau: +5, ... } }, ...]
  def self.weekly_trend(periods: 8)
    rows = weekly.recent(periods).to_a.reverse
    rows.each_with_index.map do |snap, i|
      prev = rows[i - 1]
      {
        recorded_on: snap.recorded_on,
        metrics: snap.metrics,
        delta: i.zero? ? nil : compute_delta(prev.metrics, snap.metrics)
      }
    end
  end

  def self.compute_delta(prev_metrics, curr_metrics)
    prev_m = prev_metrics.deep_symbolize_keys
    curr_m = curr_metrics.deep_symbolize_keys

    {
      wau:           delta_val(prev_m.dig(:users, :wau),           curr_m.dig(:users, :wau)),
      paid:          delta_val(prev_m.dig(:users, :paid),          curr_m.dig(:users, :paid)),
      posts_week:    delta_val(prev_m.dig(:posts, :this_week),     curr_m.dig(:posts, :this_week)),
      user_likes:    delta_val(prev_m.dig(:engagement, :user_likes_this_week), curr_m.dig(:engagement, :user_likes_this_week)),
      conv_rate_pct: delta_val(prev_m.dig(:posts, :conversation_rate_pct),     curr_m.dig(:posts, :conversation_rate_pct))
    }
  end
  private_class_method :compute_delta

  def self.delta_val(prev_val, curr_val)
    prev_v = prev_val.to_f
    curr_v = curr_val.to_f
    diff = (curr_v - prev_v).round(2)
    pct  = prev_v.zero? ? nil : ((diff / prev_v) * 100).round(1)
    { diff: diff, pct: pct }
  end
  private_class_method :delta_val
end
