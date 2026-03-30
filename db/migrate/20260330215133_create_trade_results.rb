class CreateTradeResults < ActiveRecord::Migration[8.1]
  def change
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
