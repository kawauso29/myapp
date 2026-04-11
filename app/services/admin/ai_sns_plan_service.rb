module Admin
  class AiSnsPlanService
    PLAN_FILE = Rails.root.join("docs/ai_sns_plan_status.yml")
    PRIORITY_ORDER = { "high" => 0, "medium" => 1, "low" => 2 }.freeze
    STATUS_ICONS = { "todo" => "⬜", "in_progress" => "🔄", "done" => "✅" }.freeze

    def self.load
      YAML.load_file(PLAN_FILE)
    end

    def self.save(plan)
      File.write(PLAN_FILE, plan.to_yaml)
    end

    def self.items
      load["items"]
    end

    def self.stats
      all = items
      {
        total:       all.count,
        done:        all.count { |_, v| v["status"] == "done" },
        in_progress: all.count { |_, v| v["status"] == "in_progress" },
        todo:        all.count { |_, v| v["status"] == "todo" }
      }
    end

    def self.next_item
      todo = items.select { |_, v| v["status"] == "todo" }
      return nil if todo.empty?

      id, item = todo.min_by { |k, v| [PRIORITY_ORDER[v["priority"]] || 99, k] }
      item.merge("id" => id)
    end

    def self.items_by_priority
      all = items
      %w[high medium low].each_with_object({}) do |priority, result|
        result[priority] = all.select { |_, v| v["priority"] == priority }
      end
    end
  end
end
