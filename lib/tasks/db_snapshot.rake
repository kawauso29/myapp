# frozen_string_literal: true

namespace :db do
  desc "Export DB snapshot as JSON to stdout (used by GitHub Actions for Claude)"
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
end
