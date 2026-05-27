# frozen_string_literal: true

namespace :db do
  SNAPSHOT_PATH = Rails.root.join("db/snapshots/db_snapshot.json")

  # スナップショット対象モデル（snapshot/snapshot_load で共有、外部キー依存順）
  # value は [クラス名文字列, limit]
  SNAPSHOT_MODELS = [
    [ "users",            "User",           10 ],
    [ "ai_users",         "AiUser",         20 ],
    [ "ai_profiles",      "AiProfile",      20 ],
    [ "ai_daily_states",  "AiDailyState",   20 ],
    [ "ai_posts",         "AiPost",         20 ],
    [ "analysis_reports", "AnalysisReport",  5 ]
  ].freeze

  desc "Export DB snapshot as JSON to stdout (used by GitHub Actions for Copilot)"
  task snapshot: :environment do
    require "json"

    conn = ActiveRecord::Base.connection
    sensitive = %w[encrypted_password reset_password_token stripe_customer_id stripe_subscription_id]

    counts = {}
    conn.tables.sort.each do |table|
      counts[table] = conn.execute("SELECT COUNT(*) FROM \"#{table}\"").first["count"].to_i
    rescue StandardError => e
      counts[table] = "error: #{e.message}"
    end

    fetch = lambda do |model, limit: 10, skip: []|
      cols = model.column_names - (sensitive + skip).map(&:to_s)
      model.select(cols).order(created_at: :desc).limit(limit).map(&:attributes)
    rescue StandardError => e
      [ { "error" => e.message } ]
    end

    snapshot = {
      generated_at: Time.current.iso8601,
      environment: Rails.env,
      counts: counts,
      recent: SNAPSHOT_MODELS.to_h do |key, class_name, limit|
        [ key, fetch.call(class_name.constantize, limit: limit) ]
      end
    }

    puts JSON.pretty_generate(snapshot)
  end

  desc "Load DB snapshot JSON into the current environment's database (for Copilot dev/test)"
  task snapshot_load: :environment do
    require "json"

    unless SNAPSHOT_PATH.exist?
      abort "Snapshot not found: #{SNAPSHOT_PATH}\nRun the 'DB Snapshot for Copilot' workflow to generate one."
    end

    data = JSON.parse(SNAPSHOT_PATH.read)
    puts "Loading snapshot generated at: #{data['generated_at']} (env: #{data['environment']})"

    SNAPSHOT_MODELS.each do |key, class_name, _limit|
      klass = class_name.constantize
      rows = data.dig("recent", key)
      next if rows.blank?

      valid_cols = klass.column_names
      records = rows.filter_map do |row|
        sliced = row.slice(*valid_cols)
        next if sliced.blank?
        sliced
      end

      next if records.empty?

      klass.upsert_all(records, unique_by: :id)
      puts "  #{key}: #{records.size} records loaded"
    rescue ActiveRecord::ActiveRecordError => e
      puts "  #{key}: skipped (ActiveRecord error - #{e.message})"
    rescue StandardError => e
      puts "  #{key}: skipped (#{e.class}: #{e.message})"
    end

    puts "Snapshot load complete."
  end
end
