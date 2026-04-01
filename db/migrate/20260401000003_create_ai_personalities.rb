class CreateAiPersonalities < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_personalities do |t|
      t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

      t.integer :sociability,         null: false, default: 3
      t.integer :post_frequency,      null: false, default: 3
      t.integer :active_time_peak,    null: false, default: 3
      t.integer :need_for_approval,   null: false, default: 3
      t.integer :emotional_range,     null: false, default: 3
      t.integer :risk_tolerance,      null: false, default: 3
      t.integer :self_expression,     null: false, default: 3
      t.integer :drinking_frequency,  null: false, default: 2
      t.integer :self_esteem,         null: false, default: 3
      t.integer :empathy,             null: false, default: 3
      t.integer :jealousy,            null: false, default: 2
      t.integer :curiosity,           null: false, default: 3
      t.integer :follow_philosophy,   null: false, default: 1

      t.integer :primary_purpose,   null: false, default: 0
      t.integer :secondary_purpose

      t.timestamps
    end
  end
end
