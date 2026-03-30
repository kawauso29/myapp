# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_30_215135) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_judgments", force: :cascade do |t|
    t.string "agent_type"
    t.float "confidence"
    t.datetime "created_at", null: false
    t.string "judgment"
    t.bigint "market_snapshot_id", null: false
    t.text "reasoning"
    t.datetime "updated_at", null: false
    t.boolean "veto"
    t.string "veto_reason"
    t.index ["market_snapshot_id"], name: "index_agent_judgments_on_market_snapshot_id"
  end

  create_table "analysis_reports", force: :cascade do |t|
    t.jsonb "agent_accuracy"
    t.datetime "created_at", null: false
    t.jsonb "good_skip_patterns"
    t.text "improvement_suggestions"
    t.jsonb "loss_patterns"
    t.datetime "period_end"
    t.datetime "period_start"
    t.string "report_type"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "market_snapshots", force: :cascade do |t|
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.float "dxy"
    t.float "nas100_price"
    t.float "nas100_volume"
    t.jsonb "raw_data"
    t.string "state", null: false
    t.float "state_confidence"
    t.datetime "updated_at", null: false
    t.float "vix"
    t.index ["captured_at"], name: "index_market_snapshots_on_captured_at"
  end

  create_table "picro_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_id", null: false
    t.boolean "notified", default: false, null: false
    t.text "preview"
    t.datetime "received_at"
    t.string "sender_name"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_picro_messages_on_message_id", unique: true
  end

  create_table "trade_decisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "decision"
    t.string "direction"
    t.float "final_score"
    t.bigint "market_snapshot_id", null: false
    t.text "skip_reason"
    t.datetime "updated_at", null: false
    t.index ["market_snapshot_id"], name: "index_trade_decisions_on_market_snapshot_id"
  end

  create_table "trade_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.float "entry_price"
    t.float "exit_price"
    t.string "outcome"
    t.float "pips"
    t.float "profit_loss"
    t.bigint "trade_decision_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trade_decision_id"], name: "index_trade_results_on_trade_decision_id"
  end

  add_foreign_key "agent_judgments", "market_snapshots"
  add_foreign_key "trade_decisions", "market_snapshots"
  add_foreign_key "trade_results", "trade_decisions"
end
