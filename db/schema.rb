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

ActiveRecord::Schema[8.1].define(version: 2026_04_28_030000) do
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

  create_table "ai_close_people", force: :cascade do |t|
    t.integer "age"
    t.date "age_base_date"
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.integer "gender"
    t.string "name", null: false
    t.text "notes"
    t.integer "relation", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "relation"], name: "index_ai_close_people_on_ai_user_id_and_relation"
    t.index ["ai_user_id"], name: "index_ai_close_people_on_ai_user_id"
  end

  create_table "ai_communities", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "description"
    t.string "emoji", default: "👥"
    t.integer "members_count", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["members_count"], name: "index_ai_communities_on_members_count"
    t.index ["name"], name: "index_ai_communities_on_name", unique: true
  end

  create_table "ai_community_memberships", force: :cascade do |t|
    t.bigint "ai_community_id", null: false
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_community_id", "ai_user_id"], name: "index_community_memberships_unique", unique: true
    t.index ["ai_community_id"], name: "index_ai_community_memberships_on_ai_community_id"
    t.index ["ai_user_id"], name: "index_ai_community_memberships_on_ai_user_id"
  end

  create_table "ai_daily_schedules", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "items", default: [], null: false
    t.date "scheduled_date", null: false
    t.text "tomorrow_note"
    t.datetime "updated_at", null: false
    t.text "week_context"
    t.index ["ai_user_id", "scheduled_date"], name: "index_ai_daily_schedules_on_ai_user_id_and_scheduled_date", unique: true
    t.index ["ai_user_id"], name: "index_ai_daily_schedules_on_ai_user_id"
    t.index ["scheduled_date"], name: "index_ai_daily_schedules_on_scheduled_date"
  end

  create_table "ai_daily_states", force: :cascade do |t|
    t.bigint "ai_user_id", null: false
    t.integer "appetite", default: 1, null: false
    t.integer "busyness", default: 1, null: false
    t.integer "concentration", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "daily_whim", default: 13, null: false
    t.date "date", null: false
    t.integer "drinking_level", default: 0, null: false
    t.integer "energy", default: 1, null: false
    t.integer "fatigue_carried", default: 0, null: false
    t.boolean "going_out", default: false, null: false
    t.boolean "hangover", default: false, null: false
    t.jsonb "hourly_states", default: [], null: false
    t.boolean "is_drinking", default: false, null: false
    t.integer "mood", default: 1, null: false
    t.integer "morning_mood", default: 2, null: false
    t.integer "physical", default: 1, null: false
    t.integer "post_motivation", default: 50, null: false
    t.integer "social_battery", default: 80, null: false
    t.integer "stress_level", default: 20, null: false
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
    t.integer "anger", default: 0, null: false
    t.integer "anxiety", default: 10, null: false
    t.integer "boredom", default: 10, null: false
    t.datetime "created_at", null: false
    t.integer "dissatisfaction", default: 10, null: false
    t.integer "excitement", default: 20, null: false
    t.integer "fatigue_carried", default: 0, null: false
    t.integer "happiness", default: 50, null: false
    t.integer "loneliness", default: 10, null: false
    t.integer "relationship_dissatisfaction", default: 0, null: false
    t.integer "relationship_duration_days", default: 0, null: false
    t.integer "self_confidence", default: 50, null: false
    t.integer "social_energy", default: 50, null: false
    t.integer "stress", default: 10, null: false
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
    t.string "chain_type"
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.integer "event_type", null: false
    t.datetime "fired_at", null: false
    t.boolean "manually_triggered", default: false, null: false
    t.bigint "parent_event_id"
    t.datetime "updated_at", null: false
    t.index ["ai_user_id", "event_type"], name: "index_ai_life_events_on_ai_user_id_and_event_type"
    t.index ["ai_user_id"], name: "index_ai_life_events_on_ai_user_id"
    t.index ["fired_at"], name: "index_ai_life_events_on_fired_at"
    t.index ["parent_event_id"], name: "index_ai_life_events_on_parent_event_id"
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
    t.integer "competitiveness", default: 3, null: false
    t.datetime "created_at", null: false
    t.integer "creativity", default: 3, null: false
    t.integer "curiosity", default: 3, null: false
    t.integer "drinking_frequency", default: 2, null: false
    t.integer "emotional_range", default: 3, null: false
    t.integer "empathy", default: 3, null: false
    t.integer "follow_philosophy", default: 1, null: false
    t.integer "generosity", default: 3, null: false
    t.integer "humor", default: 3, null: false
    t.integer "independence", default: 3, null: false
    t.integer "jealousy", default: 2, null: false
    t.integer "need_for_approval", default: 3, null: false
    t.integer "nostalgia_tendency", default: 3, null: false
    t.integer "optimism", default: 3, null: false
    t.integer "patience", default: 3, null: false
    t.integer "perfectionism", default: 3, null: false
    t.integer "post_frequency", default: 3, null: false
    t.integer "primary_purpose", default: 0, null: false
    t.integer "risk_tolerance", default: 3, null: false
    t.integer "secondary_purpose"
    t.integer "self_esteem", default: 3, null: false
    t.integer "self_expression", default: 3, null: false
    t.integer "sensitivity", default: 3, null: false
    t.integer "sociability", default: 3, null: false
    t.integer "stubbornness", default: 3, null: false
    t.integer "trustfulness", default: 3, null: false
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
    t.string "content_language", default: "ja", null: false
    t.datetime "created_at", null: false
    t.boolean "emoji_used", default: false, null: false
    t.text "image_prompt"
    t.string "image_url"
    t.integer "impressions_count", default: 0, null: false
    t.boolean "is_story", default: false, null: false
    t.boolean "is_visible", default: true, null: false
    t.integer "likes_count", default: 0, null: false
    t.integer "mood_expressed"
    t.integer "motivation_type"
    t.integer "replies_count", default: 0, null: false
    t.bigint "reply_to_post_id"
    t.datetime "story_expires_at"
    t.string "tags", default: [], array: true
    t.datetime "updated_at", null: false
    t.integer "user_likes_count", default: 0, null: false
    t.index ["ai_user_id", "created_at"], name: "index_ai_posts_on_ai_user_id_and_created_at"
    t.index ["ai_user_id"], name: "index_ai_posts_on_ai_user_id"
    t.index ["created_at"], name: "index_ai_posts_on_created_at"
    t.index ["is_story"], name: "index_ai_posts_on_is_story"
    t.index ["is_visible"], name: "index_ai_posts_on_is_visible"
    t.index ["likes_count"], name: "index_ai_posts_on_likes_count"
    t.index ["reply_to_post_id"], name: "index_ai_posts_on_reply_to_post_id"
    t.index ["story_expires_at"], name: "index_ai_posts_on_story_expires_at"
  end

  create_table "ai_profiles", force: :cascade do |t|
    t.integer "age", null: false
    t.date "age_base_date"
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
    t.text "life_story"
    t.datetime "life_story_generated_at"
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

  create_table "ai_story_reactions", force: :cascade do |t|
    t.bigint "ai_post_id", null: false
    t.datetime "created_at", null: false
    t.string "emoji", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_post_id", "user_id"], name: "index_ai_story_reactions_on_ai_post_id_and_user_id", unique: true
    t.index ["ai_post_id"], name: "index_ai_story_reactions_on_ai_post_id"
    t.index ["user_id"], name: "index_ai_story_reactions_on_user_id"
  end

  create_table "ai_users", force: :cascade do |t|
    t.string "avatar_url"
    t.date "born_on"
    t.datetime "created_at", null: false
    t.integer "followers_count", default: 0, null: false
    t.integer "following_count", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_premium_ai", default: false, null: false
    t.boolean "is_seed", default: false, null: false
    t.integer "pending_post_theme"
    t.integer "posts_count", default: 0, null: false
    t.string "preferred_language", default: "ja", null: false
    t.integer "premium_personality_template"
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

  create_table "artifact_ledgers", force: :cascade do |t|
    t.integer "artifact_type", null: false
    t.integer "artifact_version", default: 1, null: false
    t.string "author"
    t.jsonb "content", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.datetime "published_at"
    t.integer "scope_level", null: false
    t.string "service_id"
    t.bigint "source_meeting_id"
    t.bigint "source_ticket_id"
    t.integer "status", default: 0, null: false
    t.bigint "supersedes_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_type", "scope_level", "service_id"], name: "idx_artifact_ledgers_type_scope"
    t.index ["artifact_type", "title", "artifact_version"], name: "idx_artifact_ledgers_type_title_version", unique: true
    t.index ["idempotency_key"], name: "index_artifact_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["source_meeting_id"], name: "index_artifact_ledgers_on_source_meeting_id"
    t.index ["source_ticket_id"], name: "index_artifact_ledgers_on_source_ticket_id"
    t.index ["status"], name: "index_artifact_ledgers_on_status"
    t.index ["supersedes_id"], name: "index_artifact_ledgers_on_supersedes_id"
  end

  create_table "audit_decision_ledgers", force: :cascade do |t|
    t.string "audit_role", null: false
    t.string "auditor"
    t.datetime "created_at", null: false
    t.datetime "decided_at", null: false
    t.integer "decision", null: false
    t.decimal "effectiveness_override_score", precision: 5, scale: 4
    t.string "idempotency_key"
    t.string "reason_code", null: false
    t.text "reason_detail"
    t.integer "scope_level", null: false
    t.string "service_id"
    t.bigint "source_meeting_id"
    t.bigint "target_ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["decision", "reason_code"], name: "idx_audit_decision_by_reason"
    t.index ["idempotency_key"], name: "index_audit_decision_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["source_meeting_id"], name: "index_audit_decision_ledgers_on_source_meeting_id"
    t.index ["target_ticket_id"], name: "index_audit_decision_ledgers_on_target_ticket_id"
  end

  create_table "compliance_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "enforced_at"
    t.integer "law_domain", null: false
    t.string "name", null: false
    t.integer "owner_role", null: false
    t.text "pattern", null: false
    t.text "rationale"
    t.integer "scope_level", null: false
    t.string "service_id_pattern"
    t.integer "severity", null: false
    t.datetime "updated_at", null: false
    t.index ["enforced_at"], name: "index_compliance_rules_on_enforced_at"
    t.index ["law_domain", "severity"], name: "index_compliance_rules_on_law_domain_and_severity"
    t.index ["scope_level", "severity"], name: "index_compliance_rules_on_scope_level_and_severity"
  end

  create_table "cost_ledgers", force: :cascade do |t|
    t.decimal "amount_jpy", precision: 14, scale: 2, default: "0.0", null: false
    t.string "business_unit_id"
    t.datetime "created_at", null: false
    t.datetime "incurred_at", null: false
    t.datetime "recorded_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "scope_level", null: false
    t.string "service_id"
    t.integer "source", null: false
    t.string "source_artifact_id"
    t.string "source_detail"
    t.bigint "source_meeting_id"
    t.bigint "source_ticket_id"
    t.string "subject_id", null: false
    t.integer "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["incurred_at"], name: "index_cost_ledgers_on_incurred_at"
    t.index ["scope_level", "service_id"], name: "index_cost_ledgers_on_scope_level_and_service_id"
    t.index ["source_meeting_id"], name: "index_cost_ledgers_on_source_meeting_id"
    t.index ["source_ticket_id"], name: "index_cost_ledgers_on_source_ticket_id"
    t.index ["subject_type", "subject_id"], name: "index_cost_ledgers_on_subject_type_and_subject_id"
  end

  create_table "customer_feedback_ledgers", force: :cascade do |t|
    t.jsonb "categorization", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.bigint "linked_ticket_id"
    t.text "raw_text", null: false
    t.datetime "received_at", null: false
    t.integer "scope_level", null: false
    t.string "service_id"
    t.integer "source", null: false
    t.integer "status", default: 0, null: false
    t.string "submitted_by"
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_customer_feedback_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["linked_ticket_id"], name: "index_customer_feedback_ledgers_on_linked_ticket_id"
    t.index ["scope_level", "service_id", "received_at"], name: "idx_cust_feedback_scope_received"
    t.index ["status", "source"], name: "index_customer_feedback_ledgers_on_status_and_source"
  end

  create_table "dev_initiatives", force: :cascade do |t|
    t.string "category"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "item_key", null: false
    t.text "kpi_hypothesis"
    t.text "kpi_result"
    t.text "notes"
    t.string "pr_branch"
    t.integer "priority", default: 1, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["item_key"], name: "index_dev_initiatives_on_item_key", unique: true
    t.index ["status"], name: "index_dev_initiatives_on_status"
  end

  create_table "experiment_ledgers", force: :cascade do |t|
    t.string "auto_decision"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.date "deadline", null: false
    t.datetime "decided_at"
    t.string "decision_reason"
    t.string "hypothesis", null: false
    t.jsonb "kpi_targets", default: [], null: false
    t.jsonb "linked_kpis", default: [], null: false
    t.integer "scope_level", default: 2, null: false
    t.string "service_id", null: false
    t.bigint "source_ticket_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["deadline"], name: "index_experiment_ledgers_on_deadline"
    t.index ["service_id"], name: "index_experiment_ledgers_on_service_id"
    t.index ["status"], name: "index_experiment_ledgers_on_status"
  end

  create_table "hr_evaluation_ledgers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "criteria", default: {}, null: false
    t.jsonb "evidence", default: {}, null: false
    t.string "idempotency_key"
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.integer "scope_level", null: false
    t.decimal "score", precision: 5, scale: 4
    t.string "service_id"
    t.bigint "source_meeting_id"
    t.integer "status", default: 0, null: false
    t.string "subject_agent"
    t.string "subject_role", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_hr_evaluation_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["source_meeting_id"], name: "index_hr_evaluation_ledgers_on_source_meeting_id"
    t.index ["subject_role", "period_end"], name: "idx_hr_evaluation_role_period"
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

  create_table "knowledge_ledgers", force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "author"
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.integer "kind", null: false
    t.bigint "source_meeting_id"
    t.bigint "source_ticket_id"
    t.integer "status", default: 0, null: false
    t.bigint "supersedes_id"
    t.jsonb "tags", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_knowledge_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["kind", "status"], name: "index_knowledge_ledgers_on_kind_and_status"
    t.index ["source_meeting_id"], name: "index_knowledge_ledgers_on_source_meeting_id"
    t.index ["source_ticket_id"], name: "index_knowledge_ledgers_on_source_ticket_id"
    t.index ["supersedes_id"], name: "index_knowledge_ledgers_on_supersedes_id"
  end

  create_table "kpi_ledgers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "current_value", default: {}, null: false
    t.text "description"
    t.integer "grade"
    t.datetime "graded_at"
    t.string "kpi_key", null: false
    t.string "name", null: false
    t.integer "scope_level", null: false
    t.string "service_id"
    t.integer "status", default: 0, null: false
    t.jsonb "target_value", default: {}, null: false
    t.jsonb "thresholds", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["grade"], name: "index_kpi_ledgers_on_grade"
    t.index ["kpi_key"], name: "index_kpi_ledgers_on_kpi_key", unique: true
    t.index ["scope_level", "service_id"], name: "index_kpi_ledgers_on_scope_level_and_service_id"
  end

  create_table "kpi_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "metrics", null: false
    t.string "period", null: false
    t.date "recorded_on", null: false
    t.datetime "updated_at", null: false
    t.index ["period", "recorded_on"], name: "index_kpi_snapshots_on_period_and_recorded_on", unique: true
  end

  create_table "lane_capacity_caps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "operating_lane", null: false
    t.integer "scope_level"
    t.string "service_id"
    t.datetime "updated_at", null: false
    t.integer "wip_cap", default: 5, null: false
    t.index ["scope_level", "service_id", "operating_lane"], name: "idx_lane_capacity_scope_lane", unique: true
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

  create_table "meeting_definitions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "allowed_cycles", default: [], null: false
    t.string "chair_role", null: false
    t.datetime "created_at", null: false
    t.string "meeting_key", null: false
    t.integer "meeting_type", null: false
    t.jsonb "participant_roles", default: [], null: false
    t.integer "scope_level", null: false
    t.string "service_id"
    t.datetime "updated_at", null: false
    t.jsonb "writes_ledgers", default: [], null: false
    t.index ["meeting_key"], name: "index_meeting_definitions_on_meeting_key", unique: true
    t.index ["meeting_type", "scope_level"], name: "index_meeting_definitions_on_meeting_type_and_scope_level"
  end

  create_table "meeting_ledgers", force: :cascade do |t|
    t.jsonb "carry_over_items", default: [], null: false
    t.string "chair", null: false
    t.datetime "created_at", null: false
    t.jsonb "decisions", default: [], null: false
    t.jsonb "directives", default: [], null: false
    t.integer "duration_minutes"
    t.jsonb "escalations", default: [], null: false
    t.datetime "held_at", null: false
    t.decimal "hold_item_rate", precision: 5, scale: 4
    t.jsonb "hold_items", default: [], null: false
    t.string "idempotency_key"
    t.jsonb "input_materials", default: [], null: false
    t.decimal "kpi_correlation_score", precision: 5, scale: 4
    t.bigint "meeting_definition_id", null: false
    t.decimal "meeting_health_score", precision: 5, scale: 4
    t.string "meeting_key", null: false
    t.integer "meeting_type", null: false
    t.jsonb "minutes", default: {}, null: false
    t.jsonb "participants", default: [], null: false
    t.decimal "role_fill_rate", precision: 5, scale: 4
    t.integer "scope_level", null: false
    t.string "service_id"
    t.integer "status", default: 0, null: false
    t.jsonb "tickets_to_create", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_meeting_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["meeting_definition_id"], name: "index_meeting_ledgers_on_meeting_definition_id"
    t.index ["meeting_health_score"], name: "index_meeting_ledgers_on_meeting_health_score"
    t.index ["meeting_key", "held_at"], name: "index_meeting_ledgers_on_meeting_key_and_held_at"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "ai_post_id"
    t.bigint "ai_user_id"
    t.datetime "created_at", null: false
    t.boolean "is_read", default: false, null: false
    t.string "message", null: false
    t.jsonb "metadata", default: {}
    t.string "notification_type", null: false
    t.bigint "target_ai_user_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_post_id"], name: "index_notifications_on_ai_post_id"
    t.index ["ai_user_id", "notification_type", "created_at"], name: "index_notifications_on_ai_user_id_type_created_at"
    t.index ["ai_user_id"], name: "index_notifications_on_ai_user_id"
    t.index ["target_ai_user_id"], name: "index_notifications_on_target_ai_user_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "is_read"], name: "index_notifications_on_user_id_and_is_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "operator_override_ledgers", force: :cascade do |t|
    t.integer "action", null: false
    t.datetime "created_at", null: false
    t.datetime "lifted_at"
    t.string "linked_stop_ledger_id"
    t.string "operator", null: false
    t.text "reason", null: false
    t.integer "scope_level", null: false
    t.string "service_id"
    t.datetime "started_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "lifted_at"], name: "index_operator_override_ledgers_on_action_and_lifted_at"
    t.index ["scope_level", "service_id", "lifted_at"], name: "idx_operator_override_scope_lifted"
  end

  create_table "org_change_ledgers", force: :cascade do |t|
    t.integer "change_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "diff", default: {}, null: false
    t.date "effective_from"
    t.string "idempotency_key"
    t.text "rationale"
    t.integer "scope_level", null: false
    t.string "service_id"
    t.bigint "source_meeting_id"
    t.bigint "source_ticket_id"
    t.integer "status", default: 0, null: false
    t.string "subject_role"
    t.datetime "updated_at", null: false
    t.index ["change_type", "status"], name: "index_org_change_ledgers_on_change_type_and_status"
    t.index ["idempotency_key"], name: "index_org_change_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["source_meeting_id"], name: "index_org_change_ledgers_on_source_meeting_id"
    t.index ["source_ticket_id"], name: "index_org_change_ledgers_on_source_ticket_id"
  end

  create_table "organization_roles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "display_name", null: false
    t.string "role_key", null: false
    t.integer "scope_level", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_organization_roles_on_active"
    t.index ["role_key"], name: "index_organization_roles_on_role_key", unique: true
    t.index ["scope_level"], name: "index_organization_roles_on_scope_level"
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

  create_table "portfolio_strategy_ledgers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.jsonb "linked_kpis", default: [], null: false
    t.jsonb "member_service_ids", default: [], null: false
    t.date "period_end"
    t.date "period_start", null: false
    t.bigint "source_meeting_id"
    t.integer "status", default: 0, null: false
    t.string "strategy_key", null: false
    t.integer "strategy_type", null: false
    t.jsonb "targets", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_portfolio_strategy_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["source_meeting_id"], name: "index_portfolio_strategy_ledgers_on_source_meeting_id"
    t.index ["strategy_key"], name: "index_portfolio_strategy_ledgers_on_strategy_key", unique: true
    t.index ["strategy_type", "status"], name: "index_portfolio_strategy_ledgers_on_strategy_type_and_status"
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

  create_table "role_permissions", force: :cascade do |t|
    t.integer "action", null: false
    t.boolean "allowed", default: false, null: false
    t.integer "approver_role"
    t.string "audit_reason_code_required"
    t.datetime "created_at", null: false
    t.boolean "requires_dual_approval", default: false, null: false
    t.integer "role", null: false
    t.integer "scope", null: false
    t.string "service_id_pattern"
    t.integer "tiebreaker_role"
    t.datetime "updated_at", null: false
    t.index ["action", "allowed"], name: "index_role_permissions_on_action_and_allowed"
    t.index ["role", "action", "scope"], name: "index_role_permissions_on_role_and_action_and_scope"
  end

  create_table "service_heartbeats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "due_cycle", null: false
    t.datetime "last_run_at"
    t.bigint "meeting_definition_id", null: false
    t.datetime "next_run_at"
    t.string "service_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_definition_id", "service_id"], name: "idx_on_meeting_definition_id_service_id_4057f53616", unique: true
    t.index ["meeting_definition_id"], name: "index_service_heartbeats_on_meeting_definition_id"
    t.index ["status", "next_run_at"], name: "index_service_heartbeats_on_status_and_next_run_at"
  end

  create_table "service_ledgers", force: :cascade do |t|
    t.string "business_owner", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "scope_level", default: 2, null: false
    t.string "service_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["scope_level"], name: "index_service_ledgers_on_scope_level"
    t.index ["service_id"], name: "index_service_ledgers_on_service_id", unique: true
  end

  create_table "service_schedule_definitions", force: :cascade do |t|
    t.jsonb "args", default: [], null: false
    t.integer "cadence"
    t.datetime "created_at", null: false
    t.string "cron", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.string "job_class", null: false
    t.string "job_key", null: false
    t.string "queue", default: "default", null: false
    t.string "service_id"
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_service_schedule_definitions_on_enabled"
    t.index ["job_key"], name: "index_service_schedule_definitions_on_job_key", unique: true
    t.index ["service_id"], name: "index_service_schedule_definitions_on_service_id"
  end

  create_table "service_time_axis_settings", force: :cascade do |t|
    t.integer "cadence", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "interval_seconds", null: false
    t.string "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id", "cadence"], name: "idx_stas_service_cadence", unique: true
  end

  create_table "stop_ledgers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "evidence", default: {}, null: false
    t.string "idempotency_key"
    t.text "lift_reason"
    t.datetime "lifted_at"
    t.string "lifted_by"
    t.integer "scope_level", null: false
    t.string "service_id"
    t.bigint "source_meeting_id"
    t.bigint "source_ticket_id"
    t.datetime "started_at", null: false
    t.integer "status", default: 0, null: false
    t.string "trigger_detail"
    t.integer "trigger_type", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_stop_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["scope_level", "service_id", "lifted_at"], name: "idx_stop_ledger_scope_lifted"
    t.index ["source_meeting_id"], name: "index_stop_ledgers_on_source_meeting_id"
    t.index ["source_ticket_id"], name: "index_stop_ledgers_on_source_ticket_id"
    t.index ["status", "trigger_type"], name: "index_stop_ledgers_on_status_and_trigger_type"
  end

  create_table "ticket_ledgers", force: :cascade do |t|
    t.string "assignee"
    t.string "business_owner"
    t.datetime "copilot_triggered_at"
    t.datetime "created_at", null: false
    t.integer "due_cycle"
    t.date "due_date"
    t.integer "effectiveness_sample_size"
    t.decimal "effectiveness_score", precision: 5, scale: 4
    t.datetime "effectiveness_updated_at"
    t.integer "escalation_to"
    t.integer "github_issue_number"
    t.integer "github_pr_number"
    t.datetime "github_synced_at"
    t.string "idempotency_key"
    t.string "improvement_pattern_key"
    t.text "kpi_hypothesis"
    t.text "kpi_result"
    t.jsonb "linked_artifacts", default: [], null: false
    t.jsonb "linked_kpis", default: [], null: false
    t.text "notes"
    t.integer "operating_lane"
    t.string "owner_agent"
    t.string "owner_dept"
    t.string "pr_branch"
    t.integer "priority", default: 1, null: false
    t.datetime "resolved_at"
    t.integer "risk_level", default: 0
    t.integer "scope_level", null: false
    t.string "service_id"
    t.integer "sla_breach_action"
    t.datetime "sla_breached_at"
    t.datetime "sla_deadline"
    t.bigint "source_meeting_id", null: false
    t.integer "source_meeting_type"
    t.integer "status", default: 0, null: false
    t.string "template_id"
    t.string "ticket_type", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["copilot_triggered_at"], name: "index_ticket_ledgers_on_copilot_triggered_at"
    t.index ["idempotency_key"], name: "index_ticket_ledgers_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["improvement_pattern_key"], name: "index_ticket_ledgers_on_improvement_pattern_key"
    t.index ["operating_lane", "status"], name: "idx_ticket_operating_lane_status"
    t.index ["pr_branch"], name: "index_ticket_ledgers_on_pr_branch", where: "(pr_branch IS NOT NULL)"
    t.index ["service_id"], name: "index_ticket_ledgers_on_service_id"
    t.index ["sla_breached_at"], name: "index_ticket_ledgers_on_sla_breached_at"
    t.index ["sla_deadline"], name: "index_ticket_ledgers_on_sla_deadline"
    t.index ["source_meeting_id"], name: "index_ticket_ledgers_on_source_meeting_id"
    t.index ["status", "escalation_to"], name: "index_ticket_ledgers_on_status_and_escalation_to"
    t.index ["template_id"], name: "idx_ticket_ledgers_template_id", unique: true, where: "(template_id IS NOT NULL)"
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

  create_table "user_community_follows", force: :cascade do |t|
    t.bigint "ai_community_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ai_community_id"], name: "index_user_community_follows_on_ai_community_id"
    t.index ["user_id", "ai_community_id"], name: "index_user_community_follows_unique", unique: true
    t.index ["user_id"], name: "index_user_community_follows_on_user_id"
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
    t.string "preferred_language", default: "ja", null: false
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
  add_foreign_key "ai_close_people", "ai_users"
  add_foreign_key "ai_community_memberships", "ai_communities"
  add_foreign_key "ai_community_memberships", "ai_users"
  add_foreign_key "ai_daily_schedules", "ai_users"
  add_foreign_key "ai_daily_states", "ai_users"
  add_foreign_key "ai_dm_messages", "ai_dm_threads", column: "thread_id"
  add_foreign_key "ai_dm_messages", "ai_users"
  add_foreign_key "ai_dm_threads", "ai_users", column: "ai_user_a_id"
  add_foreign_key "ai_dm_threads", "ai_users", column: "ai_user_b_id"
  add_foreign_key "ai_dynamic_params", "ai_users"
  add_foreign_key "ai_interest_tags", "ai_users"
  add_foreign_key "ai_interest_tags", "interest_tags"
  add_foreign_key "ai_life_events", "ai_life_events", column: "parent_event_id"
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
  add_foreign_key "ai_story_reactions", "ai_posts"
  add_foreign_key "ai_story_reactions", "users"
  add_foreign_key "ai_users", "users"
  add_foreign_key "cost_ledgers", "meeting_ledgers", column: "source_meeting_id"
  add_foreign_key "cost_ledgers", "ticket_ledgers", column: "source_ticket_id"
  add_foreign_key "meeting_ledgers", "meeting_definitions"
  add_foreign_key "notifications", "ai_posts"
  add_foreign_key "notifications", "ai_users"
  add_foreign_key "notifications", "ai_users", column: "target_ai_user_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "post_interest_tags", "ai_posts"
  add_foreign_key "post_interest_tags", "interest_tags"
  add_foreign_key "post_reports", "ai_posts"
  add_foreign_key "post_reports", "users"
  add_foreign_key "service_heartbeats", "meeting_definitions"
  add_foreign_key "ticket_ledgers", "meeting_ledgers", column: "source_meeting_id"
  add_foreign_key "trade_decisions", "market_snapshots"
  add_foreign_key "trade_results", "trade_decisions"
  add_foreign_key "user_ai_likes", "ai_posts"
  add_foreign_key "user_ai_likes", "users"
  add_foreign_key "user_community_follows", "ai_communities"
  add_foreign_key "user_community_follows", "users"
  add_foreign_key "user_favorite_ais", "ai_users"
  add_foreign_key "user_favorite_ais", "users"
end
