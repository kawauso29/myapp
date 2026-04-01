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

ActiveRecord::Schema[8.1].define(version: 2026_04_01_200001) do
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

  create_table "ai_avatar_states", force: :cascade do |t|
    t.string "accessories", default: [], array: true
    t.bigint "ai_user_id", null: false
    t.integer "body_type", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "expression", default: 0, null: false
    t.integer "eye_type", default: 0, null: false
    t.integer "eyebrow_type", default: 0, null: false
    t.integer "face_shape", default: 0, null: false
    t.integer "hair_length", default: 0, null: false
    t.integer "hair_style", default: 0, null: false
    t.date "last_body_update_at"
    t.date "last_haircut_at"
    t.integer "outfit_bottom", default: 0, null: false
    t.integer "outfit_top", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id"], name: "index_ai_avatar_states_on_ai_user_id", unique: true
  end

  create_table "ai_daily_states", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.integer "busyness", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "daily_whim", default: 13, null: false
    t.date "date", null: false
    t.integer "drinking_level", default: 0, null: false
    t.integer "energy", default: 1, null: false
    t.integer "fatigue_carried", default: 0, null: false
    t.boolean "hangover", default: false, null: false
    t.boolean "is_drinking", default: false, null: false
    t.integer "mood", default: 1, null: false
    t.integer "physical", default: 1, null: false
    t.integer "post_motivation", default: 50, null: false
    t.integer "timeline_urge", default: 1, null: false
    t.string "today_events", default: [], array: true
    t.datetime "updated_at", null: false
    t.integer "weather_condition"
    t.integer "weather_temp"
    t.index ["ai_user_id", "date"], name: "index_ai_daily_states_on_ai_user_id_and_date", unique: true
    t.index ["ai_user_id"], name: "index_ai_daily_states_on_ai_user_id"
    t.index ["date"], name: "index_ai_daily_states_on_date"
  end

  create_table "ai_dm_messages", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "dm_type"
    t.bigint "thread_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id"], name: "index_ai_dm_messages_on_ai_user_id"
    t.index ["thread_id", "created_at"], name: "index_ai_dm_messages_on_thread_id_and_created_at"
    t.index ["thread_id"], name: "index_ai_dm_messages_on_thread_id"
  end

  create_table "ai_dm_threads", force: :cascade do |t|
    t.bigint "ai_user_a_id", null: false
    t.bigint "ai_user_b_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_message_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_a_id", "ai_user_b_id"], name: "index_ai_dm_threads_on_ai_user_a_id_and_ai_user_b_id", unique: true
    t.index ["ai_user_a_id"], name: "index_ai_dm_threads_on_ai_user_a_id"
    t.index ["ai_user_b_id"], name: "index_ai_dm_threads_on_ai_user_b_id"
    t.index ["last_message_at"], name: "index_ai_dm_threads_on_last_message_at"
    t.index ["status"], name: "index_ai_dm_threads_on_status"
  end

  create_table "ai_dynamic_params", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.integer "boredom", default: 10, null: false
    t.datetime "created_at", null: false
    t.integer "dissatisfaction", default: 10, null: false
    t.integer "fatigue_carried", default: 0, null: false
    t.integer "happiness", default: 50, null: false
    t.integer "loneliness", default: 10, null: false
    t.integer "relationship_dissatisfaction", default: 0, null: false
    t.integer "relationship_duration_days", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id"], name: "index_ai_dynamic_params_on_ai_user_id", unique: true
  end

  create_table "ai_interest_tags", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.bigint "interest_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "interest_tag_id"], name: "index_ai_interest_tags_on_ai_user_id_and_interest_tag_id", unique: true
    t.index ["ai_user_id"], name: "index_ai_interest_tags_on_ai_user_id"
    t.index ["interest_tag_id"], name: "index_ai_interest_tags_on_interest_tag_id"
  end

  create_table "ai_life_events", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.integer "event_type", null: false
    t.datetime "fired_at", null: false
    t.boolean "manually_triggered", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "event_type"], name: "index_ai_life_events_on_ai_user_id_and_event_type"
    t.index ["ai_user_id"], name: "index_ai_life_events_on_ai_user_id"
    t.index ["fired_at"], name: "index_ai_life_events_on_fired_at"
  end

  create_table "ai_long_term_memories", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "importance", default: 3, null: false
    t.integer "memory_type", null: false
    t.date "occurred_on", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "importance", "occurred_on"], name: "idx_on_ai_user_id_importance_occurred_on_3b20820d8a"
    t.index ["ai_user_id"], name: "index_ai_long_term_memories_on_ai_user_id"
  end

  create_table "ai_personalities", force: :cascade do |t|
    t.integer "active_time_peak", default: 3, null: false
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.integer "curiosity", default: 3, null: false
    t.integer "drinking_frequency", default: 2, null: false
    t.integer "emotional_range", default: 3, null: false
    t.integer "empathy", default: 3, null: false
    t.integer "follow_philosophy", default: 1, null: false
    t.integer "jealousy", default: 2, null: false
    t.integer "need_for_approval", default: 3, null: false
    t.integer "post_frequency", default: 3, null: false
    t.integer "primary_purpose", default: 0, null: false
    t.integer "risk_tolerance", default: 3, null: false
    t.integer "secondary_purpose"
    t.integer "self_esteem", default: 3, null: false
    t.integer "self_expression", default: 3, null: false
    t.integer "sociability", default: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id"], name: "index_ai_personalities_on_ai_user_id", unique: true
  end

  create_table "ai_post_likes", force: :cascade do |t|
    t.bigint "ai_post_id", null: false
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_post_id"], name: "index_ai_post_likes_on_ai_post_id"
    t.index ["ai_user_id", "ai_post_id"], name: "index_ai_post_likes_on_ai_user_id_and_ai_post_id", unique: true
    t.index ["ai_user_id"], name: "index_ai_post_likes_on_ai_user_id"
  end

  create_table "ai_posts", force: :cascade do |t|
    t.integer "ai_likes_count", default: 0, null: false
    t.bigint "ai_user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.boolean "emoji_used", default: false, null: false
    t.integer "impressions_count", default: 0, null: false
    t.boolean "is_visible", default: true, null: false
    t.integer "likes_count", default: 0, null: false
    t.integer "mood_expressed"
    t.integer "motivation_type"
    t.integer "replies_count", default: 0, null: false
    t.bigint "reply_to_post_id"
    t.string "tags", default: [], array: true
    t.datetime "updated_at", null: false
    t.integer "user_likes_count", default: 0, null: false
    t.index ["ai_user_id", "created_at"], name: "index_ai_posts_on_ai_user_id_and_created_at"
    t.index ["ai_user_id"], name: "index_ai_posts_on_ai_user_id"
    t.index ["created_at"], name: "index_ai_posts_on_created_at"
    t.index ["is_visible"], name: "index_ai_posts_on_is_visible"
    t.index ["likes_count"], name: "index_ai_posts_on_likes_count"
    t.index ["reply_to_post_id"], name: "index_ai_posts_on_reply_to_post_id"
  end

  create_table "ai_profiles", force: :cascade do |t|
    t.integer "age", null: false
    t.bigint "ai_user_id", null: false
    t.text "bio"
    t.string "catchphrase"
    t.datetime "created_at", null: false
    t.string "disliked_personality_types", default: [], array: true
    t.integer "family_structure"
    t.string "favorite_foods", default: [], array: true
    t.string "favorite_music", default: [], array: true
    t.string "favorite_places", default: [], array: true
    t.integer "gender"
    t.string "hobbies", default: [], array: true
    t.integer "life_stage"
    t.string "location"
    t.string "name", null: false
    t.integer "num_children", default: 0, null: false
    t.string "occupation"
    t.integer "occupation_type"
    t.text "personality_note"
    t.integer "relationship_status"
    t.string "strengths", default: [], array: true
    t.datetime "updated_at", null: false
    t.string "values", default: [], array: true
    t.string "weaknesses", default: [], array: true
    t.integer "youngest_child_age"
    t.index ["ai_user_id"], name: "index_ai_profiles_on_ai_user_id", unique: true
  end

  create_table "ai_relationship_memories", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.date "last_updated_on"
    t.text "summary", null: false
    t.bigint "target_ai_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "target_ai_user_id"], name: "idx_on_ai_user_id_target_ai_user_id_7468a7c27a", unique: true
    t.index ["ai_user_id"], name: "index_ai_relationship_memories_on_ai_user_id"
    t.index ["target_ai_user_id"], name: "index_ai_relationship_memories_on_target_ai_user_id"
  end

  create_table "ai_relationships", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.integer "follow_intention", default: 0, null: false
    t.integer "interaction_score", default: 0, null: false
    t.integer "interest_match", default: 0, null: false
    t.boolean "is_following", default: false, null: false
    t.datetime "last_interaction_at"
    t.integer "obligation", default: 0, null: false
    t.integer "popularity_appeal", default: 0, null: false
    t.integer "proximity", default: 0, null: false
    t.integer "relationship_type", default: 0, null: false
    t.bigint "target_ai_user_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usefulness", default: 0, null: false
    t.index ["ai_user_id", "target_ai_user_id"], name: "index_ai_relationships_on_ai_user_id_and_target_ai_user_id", unique: true
    t.index ["ai_user_id"], name: "index_ai_relationships_on_ai_user_id"
    t.index ["is_following"], name: "index_ai_relationships_on_is_following"
    t.index ["relationship_type"], name: "index_ai_relationships_on_relationship_type"
    t.index ["target_ai_user_id"], name: "index_ai_relationships_on_target_ai_user_id"
  end

  create_table "ai_short_term_memories", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.integer "importance", default: 1, null: false
    t.integer "memory_type", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "expires_at"], name: "index_ai_short_term_memories_on_ai_user_id_and_expires_at"
    t.index ["ai_user_id"], name: "index_ai_short_term_memories_on_ai_user_id"
    t.index ["expires_at"], name: "index_ai_short_term_memories_on_expires_at"
  end

  create_table "ai_users", force: :cascade do |t|
    t.string "avatar_url"
    t.date "born_on"
    t.datetime "created_at", null: false
    t.integer "followers_count", default: 0, null: false
    t.integer "following_count", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_seed", default: false, null: false
    t.integer "pending_post_theme"
    t.integer "posts_count", default: 0, null: false
    t.integer "total_likes", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "username", null: false
    t.integer "violation_count", default: 0, null: false
    t.index ["followers_count"], name: "index_ai_users_on_followers_count"
    t.index ["is_active"], name: "index_ai_users_on_is_active"
    t.index ["is_seed"], name: "index_ai_users_on_is_seed"
    t.index ["user_id"], name: "index_ai_users_on_user_id"
    t.index ["username"], name: "index_ai_users_on_username", unique: true
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

  create_table "interest_tags", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.index ["category"], name: "index_interest_tags_on_category"
    t.index ["name"], name: "index_interest_tags_on_name", unique: true
    t.index ["usage_count"], name: "index_interest_tags_on_usage_count"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
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

  create_table "post_interest_tags", force: :cascade do |t|
    t.bigint "ai_post_id", null: false
    t.datetime "created_at", null: false
    t.bigint "interest_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_post_id", "interest_tag_id"], name: "index_post_interest_tags_on_ai_post_id_and_interest_tag_id", unique: true
    t.index ["ai_post_id"], name: "index_post_interest_tags_on_ai_post_id"
    t.index ["interest_tag_id"], name: "index_post_interest_tags_on_interest_tag_id"
  end

  create_table "post_reports", force: :cascade do |t|
    t.bigint "ai_post_id", null: false
    t.datetime "created_at", null: false
    t.text "detail"
    t.integer "reason", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_post_id", "status"], name: "index_post_reports_on_ai_post_id_and_status"
    t.index ["ai_post_id"], name: "index_post_reports_on_ai_post_id"
    t.index ["status"], name: "index_post_reports_on_status"
    t.index ["user_id"], name: "index_post_reports_on_user_id"
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

  create_table "user_ai_likes", force: :cascade do |t|
    t.bigint "ai_post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_post_id"], name: "index_user_ai_likes_on_ai_post_id"
    t.index ["user_id", "ai_post_id"], name: "index_user_ai_likes_on_user_id_and_ai_post_id", unique: true
    t.index ["user_id"], name: "index_user_ai_likes_on_user_id"
  end

  create_table "user_favorite_ais", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_user_id"], name: "index_user_favorite_ais_on_ai_user_id"
    t.index ["user_id", "ai_user_id"], name: "index_user_favorite_ais_on_user_id_and_ai_user_id", unique: true
    t.index ["user_id"], name: "index_user_favorite_ais_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "expo_push_token"
    t.integer "owner_score", default: 0, null: false
    t.integer "plan", default: 0, null: false
    t.datetime "plan_expires_at"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["expo_push_token"], name: "index_users_on_expo_push_token"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "agent_judgments", "market_snapshots"
  add_foreign_key "ai_avatar_states", "ai_users"
  add_foreign_key "ai_daily_states", "ai_users"
  add_foreign_key "ai_dm_messages", "ai_dm_threads", column: "thread_id"
  add_foreign_key "ai_dm_messages", "ai_users"
  add_foreign_key "ai_dm_threads", "ai_users", column: "ai_user_a_id"
  add_foreign_key "ai_dm_threads", "ai_users", column: "ai_user_b_id"
  add_foreign_key "ai_dynamic_params", "ai_users"
  add_foreign_key "ai_interest_tags", "ai_users"
  add_foreign_key "ai_interest_tags", "interest_tags"
  add_foreign_key "ai_life_events", "ai_users"
  add_foreign_key "ai_long_term_memories", "ai_users"
  add_foreign_key "ai_personalities", "ai_users"
  add_foreign_key "ai_post_likes", "ai_posts"
  add_foreign_key "ai_post_likes", "ai_users"
  add_foreign_key "ai_posts", "ai_posts", column: "reply_to_post_id"
  add_foreign_key "ai_posts", "ai_users"
  add_foreign_key "ai_profiles", "ai_users"
  add_foreign_key "ai_relationship_memories", "ai_users"
  add_foreign_key "ai_relationship_memories", "ai_users", column: "target_ai_user_id"
  add_foreign_key "ai_relationships", "ai_users"
  add_foreign_key "ai_relationships", "ai_users", column: "target_ai_user_id"
  add_foreign_key "ai_short_term_memories", "ai_users"
  add_foreign_key "ai_users", "users"
  add_foreign_key "post_interest_tags", "ai_posts"
  add_foreign_key "post_interest_tags", "interest_tags"
  add_foreign_key "post_reports", "ai_posts"
  add_foreign_key "post_reports", "users"
  add_foreign_key "trade_decisions", "market_snapshots"
  add_foreign_key "trade_results", "trade_decisions"
  add_foreign_key "user_ai_likes", "ai_posts"
  add_foreign_key "user_ai_likes", "users"
  add_foreign_key "user_favorite_ais", "ai_users"
  add_foreign_key "user_favorite_ais", "users"
end
