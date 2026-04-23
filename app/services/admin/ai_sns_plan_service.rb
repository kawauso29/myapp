module Admin
  # PR2: AI SNS 計画項目の参照先を `TicketLedger` に切替えたバージョン。
  # 旧 `DevInitiative` テーブルは read-only 化（`Ledgers::AiSnsPlanSync` の after_save mirror で
  # TicketLedger に複写される）。本サービスは TicketLedger の `ai_sns_plan` スコープを正本として読む。
  #
  # ステータス対応（DevInitiative → TicketLedger）:
  #   todo        → draft
  #   in_progress → executing
  #   done        → completed
  class AiSnsPlanService
    STATUS_ICONS = { "todo" => "⬜", "in_progress" => "🔄", "done" => "✅" }.freeze

    # TicketLedger の status enum 値 → 旧 DevInitiative の status 文字列にマッピングする。
    LEDGER_TO_LEGACY_STATUS = {
      "draft" => "todo",
      "executing" => "in_progress",
      "completed" => "done"
    }.freeze

    def self.stats
      relation = TicketLedger.ai_sns_plan
      counts = relation.group(:status).count
      {
        total:       relation.count,
        done:        counts["completed"] || 0,
        in_progress: counts["executing"] || 0,
        todo:        counts["draft"] || 0
      }
    end

    def self.next_item
      t = TicketLedger.ai_sns_plan.status_draft.order(priority: :desc, idempotency_key: :asc).first
      return nil unless t

      {
        "id"       => t.ai_sns_plan_item_key,
        "title"    => t.title,
        "category" => t.improvement_pattern_key,
        "priority" => t.priority,
        "notes"    => legacy_notes_for(t.ai_sns_plan_item_key)
      }
    end

    def self.items_by_priority
      relation = TicketLedger.ai_sns_plan.order(priority: :desc, idempotency_key: :asc)
      %w[high medium low].each_with_object({}) do |priority, result|
        result[priority] = relation.where(priority: TicketLedger.priorities[priority]).map { |t|
          item_key = t.ai_sns_plan_item_key
          [item_key, {
            "title"        => t.title,
            "category"     => t.improvement_pattern_key,
            "status"       => LEDGER_TO_LEGACY_STATUS[t.status] || t.status,
            "priority"     => t.priority,
            "notes"        => legacy_notes_for(item_key),
            "pr_branch"    => t.pr_branch,
            "completed_at" => t.due_date&.to_s
          }]
        }.to_h
      end
    end

    # `notes` 列は TicketLedger 側に存在しないため、レガシーの DevInitiative を read-only で
    # 参照して返す（PR3 で TicketLedger に notes 相当列を持たせるか別表現に置き換える予定）。
    def self.legacy_notes_for(item_key)
      return nil if item_key.blank?

      DevInitiative.find_by(item_key: item_key)&.notes
    rescue StandardError
      nil
    end
  end
end
