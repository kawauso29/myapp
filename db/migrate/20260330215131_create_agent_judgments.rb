class CreateAgentJudgments < ActiveRecord::Migration[8.1]
  def change
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
  end
end
