# frozen_string_literal: true

# linestamp:validate_imports
# ------------------------------------------------------------------
# pending/*.rb の seed ファイルを「本番に触れず」検証する CI 用タスク。
#
# CI(rspec)は apply_imports spec が実 pending を eval 前に applied 扱いに
# するため、slug ミスや構造エラーがグリーンのまま本番 apply で初めて落ちる。
# このタスクは pending を実際に eval してマージ前に検出する。
#
#   - masters を seed(test 環境では masters.rb 末尾が自動 call しないため明示)
#   - research_slug は本番 apply 済みデータ依存 → 検証用スタブを自動生成し、
#     upsert_brand! の存在チェックを通してその先(theme/attribute/stamp)まで検証
#   - 各ファイルを必ず ROLLBACK するトランザクション内で eval(非破壊)
#   - 失敗があれば利用可能 slug 一覧を出して exit 1
# ------------------------------------------------------------------
namespace :linestamp do
  desc "Validate pending seed import files without persisting (CI pre-merge gate)"
  task validate_imports: :environment do
    pending_dir = Rails.root.join("db/seeds/linestamp/imports/pending")
    files = Dir.glob(pending_dir.join("*.rb"))
               .reject { |p| File.basename(p).start_with?("test_") }
               .sort

    if files.empty?
      puts "[validate_imports] 検証対象の pending seed はありません。"
      next
    end

    # slug 解決に master が必須。masters.rb は Rails.env.test? では自動実行
    # されない(ファイル末尾ガード)ため、ここで明示的に seed する。
    load Rails.root.join("db/seeds/linestamp/masters.rb")
    Linestamp::Seeds.call

    failures = []

    files.each do |path|
      name = File.basename(path)
      src  = File.read(path)
      begin
        ActiveRecord::Base.transaction do
          # research lineage は本番 apply 済みデータに依存するため、参照されて
          # いる research_slug の検証用スタブを用意して存在チェックを通す。
          # (research の有無自体は本番状態の問題で CI では判定不能)
          src.scan(/research_slug:\s*["']([^"']+)["']/).flatten.uniq.each do |slug|
            Linestamp::Research.find_or_create_by!(slug: slug) do |r|
              r.title = "[validate stub] #{slug}"
            end
          end

          eval(src, TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
          raise ActiveRecord::Rollback # 検証のみ。本番非破壊。
        end
        puts "  ✓ #{name}"
      rescue StandardError => e
        failures << { file: name, error: "#{e.class}: #{e.message}" }
        puts "  ✗ #{name}  ->  #{e.class}: #{e.message}"
      end
    end

    if failures.any?
      puts ""
      puts "========================================"
      puts "[validate_imports] #{failures.size} 件の seed が検証に失敗しました。"
      failures.each { |f| puts "  - #{f[:file]}: #{f[:error]}" }
      puts ""
      puts "--- 利用可能な master slug(この中から選ぶこと)---"
      puts "communication_themes: #{Linestamp::CommunicationTheme.order(:position).pluck(:slug).join(' ')}"
      Linestamp::AttributeAxis.order(:position).each do |ax|
        slugs = Linestamp::AttributeValue.where(axis: ax).order(:position).pluck(:slug)
        puts "#{ax.slug}: #{slugs.join(' ')}"
      end
      puts "========================================"
      abort("[validate_imports] FAILED")
    end

    puts ""
    puts "[validate_imports] 全 #{files.size} 件 OK。"
  end
end
