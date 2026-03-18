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

ActiveRecord::Schema[8.1].define(version: 2026_03_17_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
end
