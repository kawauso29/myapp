module Admin
  class ProjectProgressService
    GITHUB_ACTIONS_MIGRATION_FILE = Rails.root.join("docs/projects/github-actions-migration.md")
    TODO_SECTION_HEADER = "## 6. 今後のアクション（TODO）".freeze

    def self.github_actions_migration
      lines = extract_todo_lines(File.read(GITHUB_ACTIONS_MIGRATION_FILE))
      done_count = lines.count { |line| line.start_with?("- [x]") }
      total_count = lines.count

      {
        total: total_count,
        done: done_count,
        pending: total_count - done_count,
        progress_percent: total_count.positive? ? (done_count.to_f / total_count * 100).round : 0,
        items: lines.map { |line| parse_todo_line(line) }
      }
    rescue => e
      Rails.logger.warn("ProjectProgressService.github_actions_migration failed: #{e.message}")
      { total: 0, done: 0, pending: 0, progress_percent: 0, items: [] }
    end

    def self.extract_todo_lines(content)
      section = content.split(TODO_SECTION_HEADER, 2).last.to_s
      section = section.split(/^##\s+/).first.to_s
      section.lines.map(&:strip).select { |line| line.match?(/^- \[[x ]\]/) }
    end

    def self.parse_todo_line(line)
      {
        done: line.start_with?("- [x]"),
        text: line.sub(/^- \[[x ]\]\s*/, "")
      }
    end
  end
end
