class CreatePortfolioStrategyLedgers < ActiveRecord::Migration[8.1]
  # Phase 41 / §4.2: ポートフォリオ層の戦略台帳（スケルトン）。
  #
  # 複数サービスの配分・シナジー・撤退判断をサービス層より上で記録する。
  # `scope_level: :portfolio` / `:cross_service` の会議からしか書き込まない。
  def change
    create_table :portfolio_strategy_ledgers do |t|
      t.string :strategy_key, null: false
      t.string :title, null: false

      # ポートフォリオに含めるサービス群
      t.jsonb :member_service_ids, default: [], null: false

      # 0: kpi_allocation / 1: investment / 2: exit / 3: merger / 4: rebalance
      t.integer :strategy_type, null: false

      # 0: draft / 1: active / 2: paused / 3: completed / 4: abandoned
      t.integer :status, default: 0, null: false

      t.jsonb :targets, default: {}, null: false
      t.jsonb :linked_kpis, default: [], null: false

      t.date :period_start, null: false
      t.date :period_end

      t.bigint :source_meeting_id
      t.string :idempotency_key

      t.timestamps
    end

    add_index :portfolio_strategy_ledgers, :strategy_key, unique: true
    add_index :portfolio_strategy_ledgers, [ :strategy_type, :status ]
    add_index :portfolio_strategy_ledgers, :source_meeting_id
    add_index :portfolio_strategy_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
  end
end
