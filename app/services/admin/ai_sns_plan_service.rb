module Admin
  class AiSnsPlanService
    STATUS_ICONS = { "todo" => "⬜", "in_progress" => "🔄", "done" => "✅" }.freeze

    def self.stats
      {
        total:       DevInitiative.count,
        done:        DevInitiative.status_done.count,
        in_progress: DevInitiative.status_in_progress.count,
        todo:        DevInitiative.status_todo.count
      }
    end

    def self.next_item
      d = DevInitiative.next_todo.first
      return nil unless d

      {
        "id"       => d.item_key,
        "title"    => d.title,
        "category" => d.category,
        "priority" => d.priority,
        "notes"    => d.notes
      }
    end

    def self.items_by_priority
      %w[high medium low].each_with_object({}) do |priority, result|
        result[priority] = DevInitiative.where(priority: priority).ordered.map { |d|
          [d.item_key, {
            "title"    => d.title,
            "category" => d.category,
            "status"   => d.status,
            "priority" => d.priority,
            "notes"    => d.notes,
            "pr_branch"    => d.pr_branch,
            "completed_at" => d.completed_at&.to_date&.to_s
          }]
        }.to_h
      end
    end
  end
end
