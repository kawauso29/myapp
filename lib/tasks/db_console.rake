# frozen_string_literal: true

# Copilot coding agent 向け DB 操作補助タスク
# テスト環境での実装精度向上を目的とした、DB 構造確認・データ閲覧・任意 SQL 実行タスク群。
#
# 使い方:
#   RAILS_ENV=test bin/rails db:structure
#   RAILS_ENV=test bin/rails db:sample_data
#   RAILS_ENV=test bin/rails "db:query[SELECT * FROM ai_users LIMIT 5]"

namespace :db do
  desc "全テーブルのカラム定義（名前・型・null許可・デフォルト値）とレコード件数を出力する"
  task structure: :environment do
    require "json"

    conn = ActiveRecord::Base.connection
    tables = conn.tables.sort

    result = tables.map do |table|
      count = conn.execute("SELECT COUNT(*) FROM \"#{table}\"").first["count"].to_i
      columns = conn.columns(table).map do |col|
        {
          name: col.name,
          type: col.sql_type,
          null: col.null,
          default: col.default
        }
      end
      { table: table, count: count, columns: columns }
    rescue StandardError => e
      { table: table, error: e.message }
    end

    result.each do |t|
      if t[:error]
        puts "#{t[:table]} [ERROR: #{t[:error]}]"
        next
      end
      puts "\n=== #{t[:table]} (#{t[:count]} rows) ==="
      t[:columns].each do |c|
        nullable = c[:null] ? "nullable" : "NOT NULL"
        default_str = c[:default] ? " default=#{c[:default]}" : ""
        puts "  #{c[:name].ljust(30)} #{c[:type].ljust(20)} #{nullable}#{default_str}"
      end
    end
  end

  desc "各テーブルの最新 N 件をまとめて JSON 出力する（N はデフォルト5件、db:sample_data[10] で変更可）"
  task :sample_data, [ :limit ] => :environment do |_t, args|
    require "json"

    limit = [ (args[:limit] || 5).to_i, 1000 ].min
    conn = ActiveRecord::Base.connection
    tables = conn.tables.sort
    sensitive = %w[encrypted_password reset_password_token stripe_customer_id stripe_subscription_id]

    result = {}
    tables.each do |table|
      cols = conn.columns(table).map(&:name) - sensitive
      quoted_cols = cols.map { |c| "\"#{c}\"" }.join(", ")
      has_id = cols.include?("id")
      order_clause = has_id ? "ORDER BY id DESC" : ""
      rows = conn.execute(
        "SELECT #{quoted_cols} FROM \"#{table}\" #{order_clause} LIMIT #{limit}"
      ).to_a
      result[table] = rows
    rescue StandardError => e
      result[table] = { error: e.message }
    end

    puts JSON.pretty_generate(result)
  end

  SAFE_SQL_PATTERN = /\A\s*(SELECT|EXPLAIN|SHOW|WITH\s)/i
  UNSAFE_SQL_KEYWORDS = /\b(INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE|REPLACE|GRANT|REVOKE)\b/i

  desc "任意の SQL を実行して結果を JSON で出力する（読み取り専用推奨）。例: bin/rails \"db:query[SELECT * FROM ai_users LIMIT 3]\""
  task :query, [ :sql ] => :environment do |_t, args|
    require "json"

    sql = args[:sql]
    if sql.blank?
      puts "Usage: bin/rails \"db:query[SELECT * FROM table LIMIT 5]\""
      exit 1
    end

    unless sql.match?(SAFE_SQL_PATTERN)
      $stderr.puts "Warning: Non-SELECT statement detected. Only read operations are recommended."
      $stderr.puts "         Proceed with caution. Use RAILS_ENV=test to avoid affecting production data."
    end

    if sql.match?(UNSAFE_SQL_KEYWORDS)
      $stderr.puts "Blocked: Destructive SQL keywords detected (#{sql.match(UNSAFE_SQL_KEYWORDS)[0].upcase})."
      $stderr.puts "         Use bin/rails runner for write operations if intentional."
      exit 1
    end

    result = ActiveRecord::Base.connection.execute(sql).to_a
    puts JSON.pretty_generate(result)
  rescue ActiveRecord::StatementInvalid => e
    puts "SQL Error: #{e.message}"
    exit 1
  end
end
