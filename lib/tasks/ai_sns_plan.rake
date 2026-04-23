namespace :ai_sns_plan do
  # PR4: 参照先を `TicketLedger.ai_sns_plan` に切替（旧 `DevInitiative` は read-only）。
  # ステータス対応:
  #   旧 todo        → TicketLedger draft
  #   旧 in_progress → TicketLedger executing
  #   旧 done        → TicketLedger completed
  STATUS_ICONS   = { "todo" => "⬜", "in_progress" => "🔄", "done" => "✅" }.freeze
  PRIORITY_LABEL = { "high" => "★★★ 高", "medium" => "★★☆ 中", "low" => "★☆☆ 低" }.freeze

  LEDGER_STATUS_TO_LEGACY = {
    "draft" => "todo",
    "executing" => "in_progress",
    "completed" => "done"
  }.freeze

  STATUS_LEGACY_TO_LEDGER = {
    "todo" => :draft,
    "in_progress" => :executing,
    "done" => :completed
  }.freeze

  desc "AI SNS 改良計画の進捗状況を表示"
  task status: :environment do
    base = TicketLedger.ai_sns_plan
    %w[high medium low].each do |priority|
      items = base.where(priority: TicketLedger.priorities[priority]).order(idempotency_key: :asc)
      next if items.empty?

      puts "【#{PRIORITY_LABEL[priority]}優先度】"
      items.each do |t|
        legacy_status = LEDGER_STATUS_TO_LEGACY[t.status] || t.status
        icon = STATUS_ICONS[legacy_status] || "❓"
        completed = t.status_completed? ? " (完了: #{t.updated_at&.to_date})" : ""
        puts "  #{icon} [#{t.ai_sns_plan_item_key}] #{t.title}#{completed}"
      end
      puts ""
    end

    done_count = base.status_completed.count
    total      = base.count
    pct        = total > 0 ? (done_count.to_f / total * 100).round : 0
    puts "進捗: #{done_count}/#{total} (#{pct}%)"
    puts ""

    in_progress = base.status_executing.order(priority: :desc, idempotency_key: :asc)
    if in_progress.any?
      puts "🔄 実装中:"
      in_progress.each { |t| puts "   [#{t.ai_sns_plan_item_key}] #{t.title}" }
    end
  end

  desc "次に実装すべき項目を表示"
  task next: :environment do
    t = TicketLedger.ai_sns_plan.status_draft.order(priority: :desc, idempotency_key: :asc).first
    if t.nil?
      puts "✅ 全項目完了済みです！"
      next
    end

    puts "=== 次に実装すべき項目 ==="
    puts "ID       : #{t.ai_sns_plan_item_key}"
    puts "タイトル : #{t.title}"
    puts "優先度   : #{PRIORITY_LABEL[t.priority]}"
    puts "カテゴリ : #{t.improvement_pattern_key}"
    puts "メモ     : #{t.notes}"
  end

  desc "項目のステータスを更新 (例: rails ai_sns_plan:mark[B2,done])"
  task :mark, %i[id status] => :environment do |_, args|
    id     = args[:id]
    status = args[:status]

    unless STATUS_LEGACY_TO_LEDGER.key?(status)
      abort "エラー: status は todo / in_progress / done のいずれかを指定してください"
    end

    t = TicketLedger.find_ai_sns_plan_by_item_key(id)
    abort "エラー: ID '#{id}' が見つかりません" unless t

    t.assign_attributes(status: STATUS_LEGACY_TO_LEDGER[status])
    t.due_date ||= Date.current if status == "done"
    # AI SNS 計画は自動運用フロー扱いのため Runner と同じく guard を bypass する。
    t.skip_template_guard = true
    t.skip_lane_capacity_guard = true
    t.skip_pr_guardrail = true
    t.skip_stop_guard = true
    t.save!

    icon = STATUS_ICONS[status]
    puts "#{icon} [#{t.ai_sns_plan_item_key}] #{t.title} → #{status}"
  end

  desc "全項目の状況をサマリーで表示"
  task summary: :environment do
    base  = TicketLedger.ai_sns_plan
    done  = base.status_completed.count
    wip   = base.status_executing.count
    todo  = base.status_draft.count
    total = base.count

    puts "✅ 完了: #{done}  🔄 実装中: #{wip}  ⬜ 未着手: #{todo}  合計: #{total}"
  end
end
