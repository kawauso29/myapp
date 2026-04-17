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

  # `current_value` が更新されたときに grade を自動再評価する。
  # 日次バッチ（KpiGradeEvaluateJob）の補完として機能し、値が入った瞬間に grade を反映する。
  # thresholds 未設定 / value が取れない場合は evaluate_grade が nil を返すのでスキップする。
  after_save :auto_apply_grade_if_value_changed

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

  # `current_value["value"]` を Float として返す（取得不能なら nil）。
  # `Reinforcements::Planner` / `EffectivenessRecalculator` から値抽出ロジックを統一するための公開 API。
  def numeric_current_value
    numeric_value
  end

  # `target_value["value"]` を Float として返す。
  # `target_value` が未設定の場合は `thresholds["healthy"]` を「事業目標の代理値」として
  # フォールバック利用する（Phase 2 補強 / 穴②）。これにより seed 投入時に `target_value` を
  # 個別に書かなくても Planner / EffectivenessRecalculator が動作する。
  # それでも値が取れない場合のみ nil を返す。
  def numeric_target_value
    raw = target_value.is_a?(Hash) ? (target_value["value"] || target_value[:value]) : target_value
    parsed = numeric_or_nil(raw)
    return parsed unless parsed.nil?

    threshold_for("healthy")
  end

  # `evaluate_grade` の結果を grade / graded_at に保存する。
  # 既に同じ grade であれば graded_at のみ更新する。evaluate_grade が nil の場合は何もしない。
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
    numeric_or_nil(raw)
  end

  def numeric_or_nil(raw)
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

  def auto_apply_grade_if_value_changed
    return unless saved_change_to_current_value?

    apply_grade!
  end
end
