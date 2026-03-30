class CreateTradeDecisions < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_decisions do |t|
      t.references :market_snapshot, null: false, foreign_key: true
      t.float :final_score
      t.string :decision
      t.string :direction
      t.text :skip_reason

      t.timestamps
    end
  end
end
