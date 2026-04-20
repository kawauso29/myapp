class AddGradeAndThresholdsToKpiLedgers < ActiveRecord::Migration[8.1]
  def change
    # 補強5 / Phase 34: KPI 評価の段階化（healthy / warning / critical）
    unless column_exists?(:kpi_ledgers, :grade)
      add_column :kpi_ledgers, :grade, :integer
    end
    unless column_exists?(:kpi_ledgers, :graded_at)
      add_column :kpi_ledgers, :graded_at, :datetime
    end
    # thresholds JSON 形状:
    # { "healthy" => Numeric, "warning" => Numeric, "direction" => "higher_better"|"lower_better" }
    # healthy/warning は境界値。direction が省略された場合は "higher_better" 扱い。
    unless column_exists?(:kpi_ledgers, :thresholds)
      add_column :kpi_ledgers, :thresholds, :jsonb, default: {}, null: false
    end
    add_index :kpi_ledgers, :grade, if_not_exists: true
  end
end
