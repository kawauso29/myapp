# frozen_string_literal: true

namespace :db do
  SNAPSHOT_PATH = Rails.root.join("db/snapshots/db_snapshot.json")

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
      recent: {
        users: fetch.call(User),
        ai_users: fetch.call(AiUser, limit: 20),
        ai_profiles: fetch.call(AiProfile, limit: 20),
        ai_posts: fetch.call(AiPost, limit: 20),
        ai_daily_states: fetch.call(AiDailyState, limit: 20),
        market_snapshots: fetch.call(MarketSnapshot, limit: 5),
        trade_decisions: fetch.call(TradeDecision, limit: 10),
        trade_results: fetch.call(TradeResult, limit: 10),
        analysis_reports: fetch.call(AnalysisReport, limit: 5)
      }
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

    # モデル名 → クラスのマッピング（外部キー依存順）
    model_map = {
      "users"            => User,
      "ai_users"         => AiUser,
      "ai_profiles"      => AiProfile,
      "ai_daily_states"  => AiDailyState,
      "ai_posts"         => AiPost,
      "market_snapshots" => MarketSnapshot,
      "trade_decisions"  => TradeDecision,
      "trade_results"    => TradeResult,
      "analysis_reports" => AnalysisReport
    }

    model_map.each do |key, klass|
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
    rescue StandardError => e
      puts "  #{key}: skipped (#{e.message})"
    end

    puts "Snapshot load complete."
  end
end
