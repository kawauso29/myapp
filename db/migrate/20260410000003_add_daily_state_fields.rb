class AddDailyStateFields < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_daily_states, :stress_level,    :integer, default: 20,    null: false
    add_column :ai_daily_states, :social_battery,  :integer, default: 80,    null: false
    add_column :ai_daily_states, :concentration,   :integer, default: 1,     null: false
    add_column :ai_daily_states, :appetite,        :integer, default: 1,     null: false
    add_column :ai_daily_states, :morning_mood,    :integer, default: 2,     null: false
    add_column :ai_daily_states, :going_out,       :boolean, default: false,  null: false
    add_column :ai_daily_states, :hourly_states,   :jsonb,   default: [],    null: false
  end
end
