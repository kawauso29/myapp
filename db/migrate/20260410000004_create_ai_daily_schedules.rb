class CreateAiDailySchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_daily_schedules do |t|
      t.references :ai_user, null: false, foreign_key: true
      t.date    :scheduled_date, null: false
      t.jsonb   :items,          null: false, default: []
      t.text    :week_context
      t.text    :tomorrow_note
      t.timestamps
    end

    add_index :ai_daily_schedules, [:ai_user_id, :scheduled_date], unique: true
    add_index :ai_daily_schedules, :scheduled_date
  end
end
