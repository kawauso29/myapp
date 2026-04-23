namespace :ai_sns_plan do
  STATUS_ICONS   = { "todo" => "⬜", "in_progress" => "🔄", "done" => "✅" }.freeze
  PRIORITY_LABEL = { "high" => "★★★ 高", "medium" => "★★☆ 中", "low" => "★☆☆ 低" }.freeze

  desc "AI SNS 改良計画の進捗状況を表示"
  task status: :environment do
    %w[high medium low].each do |priority|
      items = DevInitiative.where(priority: priority).ordered
      next if items.empty?

      puts "【#{PRIORITY_LABEL[priority]}優先度】"
      items.each do |d|
        icon = STATUS_ICONS[d.status] || "❓"
        completed = d.status_done? ? " (完了: #{d.completed_at&.to_date})" : ""
        puts "  #{icon} [#{d.item_key}] #{d.title}#{completed}"
      end
      puts ""
    end

    done_count = DevInitiative.status_done.count
    total      = DevInitiative.count
    pct        = total > 0 ? (done_count.to_f / total * 100).round : 0
    puts "進捗: #{done_count}/#{total} (#{pct}%)"
    puts ""

    in_progress = DevInitiative.status_in_progress
    if in_progress.any?
      puts "🔄 実装中:"
      in_progress.each { |d| puts "   [#{d.item_key}] #{d.title}" }
    end
  end

  desc "次に実装すべき項目を表示"
  task next: :environment do
    d = DevInitiative.next_todo.first
    if d.nil?
      puts "✅ 全項目完了済みです！"
      next
    end

    puts "=== 次に実装すべき項目 ==="
    puts "ID       : #{d.item_key}"
    puts "タイトル : #{d.title}"
    puts "優先度   : #{PRIORITY_LABEL[d.priority]}"
    puts "カテゴリ : #{d.category}"
    puts "メモ     : #{d.notes}"
  end

  desc "項目のステータスを更新 (例: rails ai_sns_plan:mark[B2,done])"
  task :mark, %i[id status] => :environment do |_, args|
    id     = args[:id]
    status = args[:status]

    unless %w[todo in_progress done].include?(status)
      abort "エラー: status は todo / in_progress / done のいずれかを指定してください"
    end

    d = DevInitiative.find_by(item_key: id)
    abort "エラー: ID '#{id}' が見つかりません" unless d

    attrs = { status: status }
    attrs[:completed_at] = Time.current   if status == "done"
    attrs[:started_at]   = nil if status == "todo"
    d.update!(attrs)

    icon = STATUS_ICONS[status]
    puts "#{icon} [#{d.item_key}] #{d.title} → #{status}"
  end

  desc "全項目の状況をサマリーで表示"
  task summary: :environment do
    done  = DevInitiative.status_done.count
    wip   = DevInitiative.status_in_progress.count
    todo  = DevInitiative.status_todo.count
    total = DevInitiative.count

    puts "✅ 完了: #{done}  🔄 実装中: #{wip}  ⬜ 未着手: #{todo}  合計: #{total}"
  end
end
