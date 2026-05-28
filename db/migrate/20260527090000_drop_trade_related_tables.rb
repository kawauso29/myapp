class DropTradeRelatedTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :trade_results, if_exists: true
    drop_table :trade_decisions, if_exists: true
    drop_table :agent_judgments, if_exists: true
    drop_table :market_snapshots, if_exists: true
  end

  def down
    create_table :market_snapshots do |t|
      t.datetime :captured_at, null: false
      t.string :state, null: false
      t.float :state_confidence
      t.float :vix
      t.float :dxy
      t.float :nas100_price
      t.float :nas100_volume
      t.jsonb :raw_data

      t.timestamps
    end
    add_index :market_snapshots, :captured_at

    create_table :agent_judgments do |t|
      t.references :market_snapshot, null: false, foreign_key: true
      t.string :agent_type
      t.string :judgment
      t.float :confidence
      t.text :reasoning
      t.boolean :veto
      t.string :veto_reason

      t.timestamps
    end

    create_table :trade_decisions do |t|
      t.references :market_snapshot, null: false, foreign_key: true
      t.float :final_score
      t.string :decision
      t.string :direction
      t.text :skip_reason

      t.timestamps
    end

    create_table :trade_results do |t|
      t.references :trade_decision, null: false, foreign_key: true
      t.string :outcome
      t.float :pips
      t.float :profit_loss
      t.integer :duration_minutes
      t.float :entry_price
      t.float :exit_price

      t.timestamps
    end
  end
end
