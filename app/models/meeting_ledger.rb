class MeetingLedger < ApplicationRecord
  belongs_to :meeting_definition

  enum :meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5,
    quarterly_review: 6,
    annual_plan: 7
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    open: 0,
    closed: 1,
    followup_pending: 2
  }, prefix: true

  validates :meeting_definition, :meeting_key, :meeting_type, :scope_level, :chair, :held_at, :status, presence: true

  # 補強15: 会議品質スコア（0.0〜1.0）の範囲バリデーション
  %i[role_fill_rate hold_item_rate kpi_correlation_score meeting_health_score].each do |attr|
    validates attr,
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
              allow_nil: true
  end
  validates :duration_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  DEFAULT_HEALTH_SCORE_THRESHOLD = 0.4

  # 補強15: 会議の機能性スコアを 4 要素から重み付け合成する。
  # 重み: 参加率 0.35 / (1 - 保留率) 0.25 / KPI 相関 0.3 / 時間適正 0.1
  # 時間適正は 15 分未満または 120 分超で線形に減衰する。
  def compute_meeting_health_score
    return nil unless [ role_fill_rate, hold_item_rate, kpi_correlation_score ].all?(&:present?)

    duration_fit =
      if duration_minutes.blank?
        0.5
      elsif duration_minutes < 15
        duration_minutes / 15.0
      elsif duration_minutes > 120
        [ 1.0 - ((duration_minutes - 120) / 60.0), 0.0 ].max
      else
        1.0
      end

    score = role_fill_rate.to_f * 0.35 +
            (1 - hold_item_rate.to_f) * 0.25 +
            kpi_correlation_score.to_f * 0.3 +
            duration_fit * 0.1
    score.clamp(0.0, 1.0).round(4)
  end

  def unhealthy?(threshold: DEFAULT_HEALTH_SCORE_THRESHOLD)
    return false if meeting_health_score.blank?

    meeting_health_score < threshold
  end
end
