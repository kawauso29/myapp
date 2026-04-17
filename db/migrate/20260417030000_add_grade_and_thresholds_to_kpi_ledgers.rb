class AddGradeAndThresholdsToKpiLedgers < ActiveRecord::Migration[8.1]
  def change
    change_table :kpi_ledgers, bulk: true do |t|
      # 補強5 / Phase 34: KPI 評価の段階化（healthy / warning / critical）
      t.integer :grade
      t.datetime :graded_at
      # thresholds JSON 形状:
      # { "healthy" => Numeric, "warning" => Numeric, "direction" => "higher_better"|"lower_better" }
      # healthy/warning は境界値。direction が省略された場合は "higher_better" 扱い。
      t.jsonb :thresholds, default: {}, null: false
    end
    add_index :kpi_ledgers, :grade
  end
end
