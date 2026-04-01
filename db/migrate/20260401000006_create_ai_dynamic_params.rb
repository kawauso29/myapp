class CreateAiDynamicParams < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_dynamic_params do |t|
      t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

      t.integer :dissatisfaction,               null: false, default: 10
      t.integer :loneliness,                    null: false, default: 10
      t.integer :happiness,                     null: false, default: 50
      t.integer :fatigue_carried,               null: false, default: 0
      t.integer :boredom,                       null: false, default: 10
      t.integer :relationship_dissatisfaction,  null: false, default: 0
      t.integer :relationship_duration_days,    null: false, default: 0

      t.timestamps
    end
  end
end
