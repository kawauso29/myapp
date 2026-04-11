require "yaml"

namespace :ai_sns_plan do
  PLAN_FILE = Rails.root.join("docs/ai_sns_plan_status.yml")
  STATUS_ICONS = { "todo" => "⬜", "in_progress" => "🔄", "done" => "✅" }.freeze
  PRIORITY_LABEL = { "high" => "★★★ 高", "medium" => "★★☆ 中", "low" => "★☆☆ 低" }.freeze
  PRIORITY_ORDER = { "high" => 0, "medium" => 1, "low" => 2 }.freeze

  def self.load_plan
    YAML.load_file(PLAN_FILE)
  end

  def self.save_plan(plan)
    File.write(PLAN_FILE, plan.to_yaml)
  end

  desc "AI SNS 改良計画の進捗状況を表示"
  task status: :environment do
    plan = Admin::AiSnsPlanService.load
    items = plan["items"]

    puts "=== AI SNS 改良計画 進捗状況 ==="
    puts ""

    %w[high medium low].each do |priority|
      priority_items = items.select { |_, v| v["priority"] == priority }
      next if priority_items.empty?

      label = PRIORITY_LABEL[priority]
      puts "【#{label}優先度】"
      priority_items.each do |id, item|
        icon = STATUS_ICONS[item["status"]] || "❓"
        completed = item["status"] == "done" ? " (完了: #{item['completed_at']})" : ""
        puts "  #{icon} [#{id}] #{item['title']}#{completed}"
      end
      puts ""
    end

    done_count = items.count { |_, v| v["status"] == "done" }
    total = items.count
    pct = total > 0 ? (done_count.to_f / total * 100).round : 0
    puts "進捗: #{done_count}/#{total} (#{pct}%)"
    puts ""

    in_progress = items.select { |_, v| v["status"] == "in_progress" }
    if in_progress.any?
      puts "🔄 実装中:"
      in_progress.each { |id, item| puts "   [#{id}] #{item['title']}" }
    end
  end

  desc "次に実装すべき項目を表示"
  task next: :environment do
    plan = Admin::AiSnsPlanService.load
    items = plan["items"]

    todo_items = items.select { |_, v| v["status"] == "todo" }
    if todo_items.empty?
      puts "✅ 全項目完了済みです！"
      next
    end

    id, item = todo_items.min_by { |k, v| [PRIORITY_ORDER[v["priority"]] || 99, k] }
    puts "=== 次に実装すべき項目 ==="
    puts "ID       : #{id}"
    puts "タイトル : #{item['title']}"
    puts "優先度   : #{PRIORITY_LABEL[item['priority']]}"
    puts "カテゴリ : #{item['category']}"
    puts "メモ     : #{item['notes']}"
  end

  desc "項目のステータスを更新 (例: rails ai_sns_plan:mark[B2,done])"
  task :mark, %i[id status] => :environment do |_, args|
    id = args[:id]
    status = args[:status]

    unless %w[todo in_progress done].include?(status)
      abort "エラー: status は todo / in_progress / done のいずれかを指定してください"
    end

    plan = Admin::AiSnsPlanService.load
    unless plan["items"].key?(id)
      abort "エラー: ID '#{id}' が見つかりません"
    end

    plan["items"][id]["status"] = status
    plan["items"][id]["completed_at"] = Time.zone.today.to_s if status == "done"
    plan["items"][id].delete("completed_at") if status == "todo"
    Admin::AiSnsPlanService.save(plan)

    icon = STATUS_ICONS[status]
    puts "#{icon} [#{id}] #{plan['items'][id]['title']} → #{status}"
  end

  desc "全項目の状況をサマリーで表示"
  task summary: :environment do
    plan = Admin::AiSnsPlanService.load
    items = plan["items"]

    done  = items.count { |_, v| v["status"] == "done" }
    wip   = items.count { |_, v| v["status"] == "in_progress" }
    todo  = items.count { |_, v| v["status"] == "todo" }
    total = items.count

    puts "✅ 完了: #{done}  🔄 実装中: #{wip}  ⬜ 未着手: #{todo}  合計: #{total}"
  end
end
