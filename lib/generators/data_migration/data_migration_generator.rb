# frozen_string_literal: true

# データ操作専用 migration ジェネレーター
#
# 使い方:
#   bin/rails generate data_migration MarkD1AsCompleted
#   bin/rails generate data_migration backfill_missing_source_meeting_ids
#   bin/rails generate data_migration seed_new_plan_items
#
# 生成されるファイル:
#   db/migrate/YYYYMMDDHHMMSS_<name>.rb
#
# 通常の `rails generate migration` との違い:
#   - データ操作専用のコメント付きテンプレートを使用
#   - 冪等ガード・down メソッドの記述例が含まれる
#   - DDL 変更（add_column 等）は通常の migration を使うこと
class DataMigrationGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  # Rails::Generators::Migration が要求する next_migration_number の実装
  def self.next_migration_number(dirname)
    next_migration_number = current_migration_number(dirname) + 1
    ActiveRecord::Migration.next_migration_number(next_migration_number)
  end

  def create_migration_file
    migration_template "data_migration.rb.tt", "db/migrate/#{file_name}.rb"
  end
end
