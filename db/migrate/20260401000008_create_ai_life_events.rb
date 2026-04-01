class CreateAiLifeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_life_events do |t|
      t.references :ai_user, null: false, foreign_key: true

      t.integer  :event_type, null: false
      t.boolean  :manually_triggered, null: false, default: false
      t.jsonb    :context, default: {}
      t.datetime :fired_at, null: false

      t.timestamps

      t.index [:ai_user_id, :event_type]
      t.index :fired_at
    end
  end
end
