class CreateAiDailyStates < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_daily_states do |t|
      t.references :ai_user, null: false, foreign_key: true
      t.date    :date,              null: false

      t.integer :physical,          null: false, default: 1
      t.integer :mood,              null: false, default: 1
      t.integer :energy,            null: false, default: 1

      t.integer :busyness,          null: false, default: 1
      t.boolean :is_drinking,       null: false, default: false
      t.integer :drinking_level,    null: false, default: 0

      t.integer :post_motivation,   null: false, default: 50
      t.integer :timeline_urge,     null: false, default: 1

      t.boolean :hangover,          null: false, default: false
      t.integer :fatigue_carried,   null: false, default: 0

      t.integer :daily_whim,        null: false, default: 13

      t.integer :weather_condition
      t.integer :weather_temp
      t.string  :today_events, array: true, default: []

      t.timestamps

      t.index [:ai_user_id, :date], unique: true
      t.index :date
    end
  end
end
