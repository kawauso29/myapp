class AddChainFieldsToAiLifeEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_life_events, :parent_event, foreign_key: { to_table: :ai_life_events }, null: true
    add_column :ai_life_events, :chain_type, :string
  end
end
