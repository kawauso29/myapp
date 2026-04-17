class KpiLedger < ApplicationRecord
  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    active: 0,
    paused: 1
  }, prefix: true

  # Phase 34 / 補強5: KPI の達成度段階。`thresholds` 値と `current_value["value"]` の比較で
  # 自動的に遷移する（`Reinforcements::KpiGradeEvaluator`）。
  enum :grade, {
    healthy: 0,
    warning: 1,
    critical: 2
  }, prefix: true

  HIGHER_BETTER = "higher_better".freeze
  LOWER_BETTER = "lower_better".freeze
  DEFAULT_DIRECTION = HIGHER_BETTER

  validates :kpi_key, :scope_level, :name, :status, presence: true
  validates :kpi_key, uniqueness: true

  # Phase 34: thresholds の direction は 2 値のみ許可。
  validate :direction_is_valid

  # `current_value["value"]` と `thresholds` から grade を算出する。
  # thresholds が設定されていない / value が取れない場合は nil を返し、grade を変えない。
  def evaluate_grade
    value = numeric_value
    return nil if value.nil?

    direction = thresholds_direction
    healthy_threshold = threshold_for("healthy")
    warning_threshold = threshold_for("warning")
    return nil if healthy_threshold.nil? || warning_threshold.nil?

    if direction == LOWER_BETTER
      return "healthy" if value <= healthy_threshold
      return "warning" if value <= warning_threshold

      "critical"
    else
      return "healthy" if value >= healthy_threshold
      return "warning" if value >= warning_threshold

      "critical"
    end
  end

  # evaluate_grade の結果を grade / graded_at に保存する（変化しない場合はタイムスタンプのみ更新）。
  def apply_grade!
    new_grade = evaluate_grade
    return nil if new_grade.nil?

    update!(grade: new_grade, graded_at: Time.current)
    new_grade
  end

  private

  def numeric_value
    return nil if current_value.blank?

    raw = current_value.is_a?(Hash) ? (current_value["value"] || current_value[:value]) : current_value
    return nil if raw.nil?

    Float(raw)
  rescue ArgumentError, TypeError
    nil
  end

  def thresholds_direction
    return DEFAULT_DIRECTION if thresholds.blank?

    value = thresholds["direction"] || thresholds[:direction]
    return DEFAULT_DIRECTION if value.blank?

    value.to_s
  end

  def threshold_for(key)
    return nil if thresholds.blank?

    raw = thresholds[key] || thresholds[key.to_sym]
    return nil if raw.nil?

    Float(raw)
  rescue ArgumentError, TypeError
    nil
  end

  def direction_is_valid
    return if thresholds.blank?

    direction = thresholds["direction"] || thresholds[:direction]
    return if direction.blank?
    return if [ HIGHER_BETTER, LOWER_BETTER ].include?(direction.to_s)

    errors.add(:thresholds, "direction must be higher_better or lower_better")
  end
end
