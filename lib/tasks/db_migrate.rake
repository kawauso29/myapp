# frozen_string_literal: true

# データ migration 健全性チェックタスク
#
# 使い方:
#   bin/rails db:migrate:lint
#
# チェック内容:
#   1. `down` メソッドが未実装（NotImplementedError のまま）の data migration を検出
#   2. `up` のみ定義で `down` が完全に未定義の migration を検出
#
# CI での利用:
#   lint ジョブに組み込む場合は `bin/rails db:migrate:lint` を追加する。

namespace :db do
  namespace :migrate do
    desc "データ migration の健全性をチェックする（down メソッド未実装の検出）"
    task lint: :environment do
      migrate_dir = Rails.root.join("db/migrate")
      issues = []

      Dir[migrate_dir.join("*.rb")].sort.each do |path|
        content = File.read(path)
        filename = File.basename(path)

        # `def down` がそもそも定義されていない migration を検出
        # （DDL変更を含む通常 migration は change のみの場合も多いので、
        #   data migration らしい命名パターンに絞る）
        data_migration_patterns = /\A(backfill|seed|mark|migrate|sync|fix|update|set|clear|populate)_/i
        base = filename.sub(/\A\d+_/, "").sub(/\.rb\z/, "")

        next unless base.match?(data_migration_patterns)

        has_down = content.match?(/^\s+def down\b/)
        has_change = content.match?(/^\s+def change\b/)

        # `change` のみ（DDL 系）はスキップ
        next if has_change && !has_down

        unless has_down
          issues << { file: filename, reason: "`down` メソッドが定義されていません" }
          next
        end

        # `down` の中身が NotImplementedError の raise のみなら警告（情報のみ）
        down_body = content[/def down\b.*?(?=\n\s+def |\z)/m]
        if down_body&.match?(/raise NotImplementedError/)
          issues << {
            file: filename,
            reason: "`down` が未実装（NotImplementedError）のままです。IrreversibleMigration か実装を入れてください",
            severity: :warning
          }
        end
      end

      if issues.empty?
        puts "✅  db:migrate:lint: 問題なし（data migration の down はすべて実装済み）"
      else
        errors   = issues.select { |i| i[:severity] != :warning }
        warnings = issues.select { |i| i[:severity] == :warning }

        warnings.each { |i| puts "⚠️   #{i[:file]}: #{i[:reason]}" }
        errors.each   { |i| puts "❌  #{i[:file]}: #{i[:reason]}" }

        if errors.any?
          puts "\n#{errors.size} 件のエラーがあります。修正してから再実行してください。"
          exit 1
        else
          puts "\n#{warnings.size} 件の警告があります（エラーではありません）。"
        end
      end
    end
  end
end
