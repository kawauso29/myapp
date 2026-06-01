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

ActiveRecord::Schema[8.1].define(version: 2026_05_29_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "linestamp_attribute_axes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "kind", null: false, comment: "tone | motif | demographic | setting"
    t.string "name", null: false, comment: "日本語 例: トーン / モチーフ / デモグラフィ / シーン"
    t.integer "position", default: 0
    t.string "slug", null: false, comment: "tone / motif / demographic / setting"
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_linestamp_attribute_axes_on_kind"
    t.index ["slug"], name: "index_linestamp_attribute_axes_on_slug", unique: true
  end

  create_table "linestamp_attribute_values", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "axis_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false, comment: "日本語 例: ゆるい / 動物 / 30代 / 在宅"
    t.integer "position", default: 0
    t.string "slug", null: false, comment: "英小文字スネーク 例: gentle / animal / age_30s / remote"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_linestamp_attribute_values_on_active"
    t.index ["axis_id", "slug"], name: "index_linestamp_attribute_values_on_axis_id_and_slug", unique: true
    t.index ["axis_id"], name: "index_linestamp_attribute_values_on_axis_id"
  end

  create_table "linestamp_brand_attribute_values", force: :cascade do |t|
    t.bigint "attribute_value_id", null: false
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 100, comment: "0-100 ブランドにおけるこの属性の強さ"
    t.index ["attribute_value_id"], name: "idx_brand_av_by_value"
    t.index ["attribute_value_id"], name: "index_linestamp_brand_attribute_values_on_attribute_value_id"
    t.index ["brand_id", "attribute_value_id"], name: "idx_brand_av_unique", unique: true
    t.index ["brand_id"], name: "index_linestamp_brand_attribute_values_on_brand_id"
  end

  create_table "linestamp_brand_communication_themes", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "communication_theme_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 100, comment: "0-100 ブランドにとってのこのテーマの中心度"
    t.index ["brand_id", "communication_theme_id"], name: "idx_brand_ct_unique", unique: true
    t.index ["brand_id"], name: "index_linestamp_brand_communication_themes_on_brand_id"
    t.index ["communication_theme_id"], name: "idx_brand_ct_by_theme"
    t.index ["communication_theme_id"], name: "idx_on_communication_theme_id_458c5076c6"
  end

  create_table "linestamp_brands", force: :cascade do |t|
    t.string "background_color_for_gen", default: "#3CB371"
    t.jsonb "base_compositions", default: []
    t.text "base_prompt"
    t.text "brand_prompt"
    t.string "character_name"
    t.jsonb "character_parts", default: {}
    t.text "concept"
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "font_spec", default: {}
    t.jsonb "identity_axes", default: {}
    t.string "imported_from"
    t.jsonb "metadata", default: {}
    t.string "persona_name", comment: "ペルソナの通称(社内コミュニケーション用)例: 在宅ワーカー田中さん"
    t.string "primary_color", default: "#FFFFFF"
    t.text "purpose_background"
    t.bigint "research_id"
    t.string "series_name"
    t.string "slug", null: false
    t.string "status", default: "planned", null: false
    t.datetime "synced_at"
    t.text "target_audience"
    t.jsonb "target_axes", default: {}
    t.jsonb "tone_axes", default: {}
    t.text "two_part_definition"
    t.datetime "updated_at", null: false
    t.index ["research_id"], name: "index_linestamp_brands_on_research_id"
    t.index ["slug"], name: "index_linestamp_brands_on_slug", unique: true
    t.index ["status"], name: "index_linestamp_brands_on_status"
  end

  create_table "linestamp_communication_themes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description", comment: "このテーマで何を伝えたいか・典型例"
    t.string "name", null: false, comment: "日本語表示名 例: 在宅ワーク報告"
    t.bigint "parent_id", comment: "階層化用(Phase 3 では NULL 運用、Phase 4 で利用検討)"
    t.integer "position", default: 0, comment: "管理画面の並び順"
    t.string "slug", null: false, comment: "英小文字スネーク 例: remote_work_report"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_linestamp_communication_themes_on_active"
    t.index ["parent_id"], name: "index_linestamp_communication_themes_on_parent_id"
    t.index ["slug"], name: "index_linestamp_communication_themes_on_slug", unique: true
  end

  create_table "linestamp_image_specs", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "background", default: "transparent"
    t.datetime "created_at", null: false
    t.jsonb "font_specs", default: []
    t.integer "height", null: false
    t.integer "margin_px", default: 10
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "width", null: false
    t.index ["slug"], name: "index_linestamp_image_specs_on_slug", unique: true
  end

  create_table "linestamp_pack_attribute_values", force: :cascade do |t|
    t.bigint "attribute_value_id", null: false
    t.datetime "created_at", null: false
    t.bigint "pack_id", null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 100
    t.index ["attribute_value_id"], name: "idx_pack_av_by_value"
    t.index ["attribute_value_id"], name: "index_linestamp_pack_attribute_values_on_attribute_value_id"
    t.index ["pack_id", "attribute_value_id"], name: "idx_pack_av_unique", unique: true
    t.index ["pack_id"], name: "index_linestamp_pack_attribute_values_on_pack_id"
  end

  create_table "linestamp_pack_communication_themes", force: :cascade do |t|
    t.bigint "communication_theme_id", null: false
    t.datetime "created_at", null: false
    t.bigint "pack_id", null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 100
    t.index ["communication_theme_id"], name: "idx_on_communication_theme_id_d12c0ad228"
    t.index ["communication_theme_id"], name: "idx_pack_ct_by_theme"
    t.index ["pack_id", "communication_theme_id"], name: "idx_pack_ct_unique", unique: true
    t.index ["pack_id"], name: "index_linestamp_pack_communication_themes_on_pack_id"
  end

  create_table "linestamp_packs", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approver_id"
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.text "excluded_elements"
    t.bigint "image_spec_id"
    t.string "imported_from"
    t.string "layer"
    t.bigint "main_source_stamp_id"
    t.jsonb "metadata", default: {}
    t.integer "position", default: 1, null: false
    t.datetime "published_at", comment: "LINE 審査承認 → 販売開始日。NULL なら未公開"
    t.integer "purchase_unit_size", default: 8, null: false, comment: "LINE申請単位 8/24/40 のいずれか。今は 8 固定運用、将来用カラム"
    t.integer "sales_count", default: 0, null: false, comment: "LINEクリエイターズマーケットからの販売数キャッシュ(手動 or 将来API同期)"
    t.string "series_theme"
    t.text "sheet_prompt"
    t.string "slug"
    t.string "status", default: "planned", null: false
    t.datetime "synced_at"
    t.bigint "tab_source_stamp_id"
    t.jsonb "target_emotions", default: []
    t.datetime "updated_at", null: false
    t.jsonb "usage_scenes", default: []
    t.text "world_view"
    t.index ["approver_id"], name: "index_linestamp_packs_on_approver_id"
    t.index ["brand_id", "position"], name: "index_linestamp_packs_on_brand_id_and_position", unique: true
    t.index ["brand_id", "slug"], name: "index_linestamp_packs_on_brand_id_and_slug", unique: true
    t.index ["brand_id"], name: "index_linestamp_packs_on_brand_id"
    t.index ["image_spec_id"], name: "index_linestamp_packs_on_image_spec_id"
    t.index ["main_source_stamp_id"], name: "index_linestamp_packs_on_main_source_stamp_id"
    t.index ["published_at"], name: "index_linestamp_packs_on_published_at"
    t.index ["sales_count"], name: "index_linestamp_packs_on_sales_count"
    t.index ["status"], name: "index_linestamp_packs_on_status"
    t.index ["tab_source_stamp_id"], name: "index_linestamp_packs_on_tab_source_stamp_id"
  end

  create_table "linestamp_research_attribute_values", force: :cascade do |t|
    t.bigint "attribute_value_id", null: false
    t.datetime "created_at", null: false
    t.bigint "research_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attribute_value_id"], name: "idx_on_attribute_value_id_1d5429cfba"
    t.index ["research_id", "attribute_value_id"], name: "idx_research_av_unique", unique: true
    t.index ["research_id"], name: "index_linestamp_research_attribute_values_on_research_id"
  end

  create_table "linestamp_research_communication_themes", force: :cascade do |t|
    t.bigint "communication_theme_id", null: false
    t.datetime "created_at", null: false
    t.bigint "research_id", null: false
    t.datetime "updated_at", null: false
    t.index ["communication_theme_id"], name: "idx_on_communication_theme_id_06c491081a"
    t.index ["research_id", "communication_theme_id"], name: "idx_research_ct_unique", unique: true
    t.index ["research_id"], name: "index_linestamp_research_communication_themes_on_research_id"
  end

  create_table "linestamp_researches", force: :cascade do |t|
    t.text "body"
    t.text "brand_ideas"
    t.text "communication_substitute_needs"
    t.datetime "created_at", null: false
    t.jsonb "emotions", default: []
    t.text "findings"
    t.string "imported_from"
    t.jsonb "keywords", default: []
    t.text "line_market_insights"
    t.jsonb "metadata", default: {}
    t.jsonb "seasons", default: []
    t.string "slug"
    t.string "source_url"
    t.string "status", default: "draft", null: false
    t.datetime "synced_at"
    t.jsonb "target_axes", default: {}
    t.string "title", null: false
    t.jsonb "tone_axes", default: {}
    t.datetime "updated_at", null: false
    t.jsonb "usage_scenes", default: []
    t.index ["slug"], name: "index_linestamp_researches_on_slug", unique: true
    t.index ["status"], name: "index_linestamp_researches_on_status"
  end

  create_table "linestamp_seed_applications", force: :cascade do |t|
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "file_path"
    t.string "file_sha256"
    t.text "result_summary"
    t.string "seed_id", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["seed_id"], name: "index_linestamp_seed_applications_on_seed_id", unique: true
    t.index ["state"], name: "index_linestamp_seed_applications_on_state"
  end

  create_table "linestamp_stamp_attribute_values", force: :cascade do |t|
    t.bigint "attribute_value_id", null: false
    t.datetime "created_at", null: false
    t.bigint "stamp_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attribute_value_id"], name: "idx_stamp_av_by_value"
    t.index ["attribute_value_id"], name: "index_linestamp_stamp_attribute_values_on_attribute_value_id"
    t.index ["stamp_id", "attribute_value_id"], name: "idx_stamp_av_unique", unique: true
    t.index ["stamp_id"], name: "index_linestamp_stamp_attribute_values_on_stamp_id"
  end

  create_table "linestamp_stamp_communication_themes", force: :cascade do |t|
    t.bigint "communication_theme_id", null: false
    t.datetime "created_at", null: false
    t.boolean "primary", default: false, comment: "true ならこのスタンプの主テーマ(必ず1つは true)"
    t.bigint "stamp_id", null: false
    t.datetime "updated_at", null: false
    t.index ["communication_theme_id"], name: "idx_on_communication_theme_id_c388dbca16"
    t.index ["communication_theme_id"], name: "idx_stamp_ct_by_theme"
    t.index ["stamp_id", "communication_theme_id"], name: "idx_stamp_ct_unique", unique: true
    t.index ["stamp_id"], name: "index_linestamp_stamp_communication_themes_on_stamp_id"
  end

  create_table "linestamp_stamps", force: :cascade do |t|
    t.text "communication_purpose"
    t.datetime "created_at", null: false
    t.string "imported_from"
    t.text "intent"
    t.string "label"
    t.jsonb "metadata", default: {}
    t.bigint "pack_id", null: false
    t.text "pose_spec"
    t.integer "position", null: false
    t.bigint "primary_communication_theme_id", comment: "stamp の主テーマ(中間表の primary=true と必ず一致させる)"
    t.text "prompt"
    t.text "props"
    t.jsonb "search_keywords", default: []
    t.text "situation"
    t.string "status", default: "planned", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.text "usage_scene"
    t.index ["pack_id", "position"], name: "index_linestamp_stamps_on_pack_id_and_position", unique: true
    t.index ["pack_id"], name: "index_linestamp_stamps_on_pack_id"
    t.index ["primary_communication_theme_id"], name: "idx_stamps_by_primary_ct"
    t.index ["primary_communication_theme_id"], name: "index_linestamp_stamps_on_primary_communication_theme_id"
    t.index ["status"], name: "index_linestamp_stamps_on_status"
  end

  create_table "linestamp_submissions", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.string "line_item_id"
    t.jsonb "metadata", default: {}
    t.bigint "pack_id", null: false
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["pack_id"], name: "index_linestamp_submissions_on_pack_id"
    t.index ["status"], name: "index_linestamp_submissions_on_status"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "owner_score", default: 0, null: false
    t.integer "plan", default: 0, null: false
    t.string "preferred_language", default: "ja", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "linestamp_attribute_values", "linestamp_attribute_axes", column: "axis_id"
  add_foreign_key "linestamp_brand_attribute_values", "linestamp_attribute_values", column: "attribute_value_id"
  add_foreign_key "linestamp_brand_attribute_values", "linestamp_brands", column: "brand_id"
  add_foreign_key "linestamp_brand_communication_themes", "linestamp_brands", column: "brand_id"
  add_foreign_key "linestamp_brand_communication_themes", "linestamp_communication_themes", column: "communication_theme_id"
  add_foreign_key "linestamp_communication_themes", "linestamp_communication_themes", column: "parent_id"
  add_foreign_key "linestamp_pack_attribute_values", "linestamp_attribute_values", column: "attribute_value_id"
  add_foreign_key "linestamp_pack_attribute_values", "linestamp_packs", column: "pack_id"
  add_foreign_key "linestamp_pack_communication_themes", "linestamp_communication_themes", column: "communication_theme_id"
  add_foreign_key "linestamp_pack_communication_themes", "linestamp_packs", column: "pack_id"
  add_foreign_key "linestamp_packs", "linestamp_brands", column: "brand_id"
  add_foreign_key "linestamp_packs", "linestamp_image_specs", column: "image_spec_id"
  add_foreign_key "linestamp_packs", "linestamp_stamps", column: "main_source_stamp_id"
  add_foreign_key "linestamp_packs", "linestamp_stamps", column: "tab_source_stamp_id"
  add_foreign_key "linestamp_packs", "users", column: "approver_id"
  add_foreign_key "linestamp_research_attribute_values", "linestamp_attribute_values", column: "attribute_value_id"
  add_foreign_key "linestamp_research_attribute_values", "linestamp_researches", column: "research_id"
  add_foreign_key "linestamp_research_communication_themes", "linestamp_communication_themes", column: "communication_theme_id"
  add_foreign_key "linestamp_research_communication_themes", "linestamp_researches", column: "research_id"
  add_foreign_key "linestamp_stamp_attribute_values", "linestamp_attribute_values", column: "attribute_value_id"
  add_foreign_key "linestamp_stamp_attribute_values", "linestamp_stamps", column: "stamp_id"
  add_foreign_key "linestamp_stamp_communication_themes", "linestamp_communication_themes", column: "communication_theme_id"
  add_foreign_key "linestamp_stamp_communication_themes", "linestamp_stamps", column: "stamp_id"
  add_foreign_key "linestamp_stamps", "linestamp_communication_themes", column: "primary_communication_theme_id"
  add_foreign_key "linestamp_stamps", "linestamp_packs", column: "pack_id"
  add_foreign_key "linestamp_submissions", "linestamp_packs", column: "pack_id"
  add_foreign_key "linestamp_brands", "linestamp_researches", column: "research_id"
end
