module Ledgers
  # サービス別 YAML（`db/seeds/plans/<service_id>.yml`）を読み、
  # 計画項目を `Ledgers::PlanItemUpserter` 経由で TicketLedger に冪等投入する。
  #
  # YAML フォーマット:
  #   service_id: ai_sns
  #   items:
  #     - item_key: C1
  #       title: "AI同士の会話スレッド可視化"
  #       priority: high             # :low / :medium / :high
  #       category: engagement       # 任意（improvement_pattern_key にマップ）
  #       kpi_hypothesis: "..."      # 任意
  #       notes: "..."               # 任意
  #       status: todo               # :todo / :in_progress / :done（省略時 :todo）
  #
  # 全操作は `find_or_create_by!` 相当で冪等。`db:seed` / `rake ledgers:seed_plans`
  # / デプロイ毎の再投入で安全に呼べる。
  class ServicePlanSeeder
    DEFAULT_PLANS_DIR = Rails.root.join("db", "seeds", "plans").freeze

    Result = Struct.new(:loaded, :upserted, :files, keyword_init: true)

    def self.call(plans_dir: DEFAULT_PLANS_DIR)
      new(plans_dir: plans_dir).call
    end

    def initialize(plans_dir:)
      @plans_dir = plans_dir
    end

    def call
      files = Dir.glob(File.join(@plans_dir.to_s, "*.{yml,yaml}")).sort
      upserted = 0

      files.each do |path|
        upserted += seed_file!(path)
      end

      Result.new(loaded: files.size, upserted: upserted, files: files)
    end

    private

    def seed_file!(path)
      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
      service_id = data["service_id"].to_s
      items = Array(data["items"])

      raise ArgumentError, "service_id missing in #{path}" if service_id.empty?

      items.each do |item|
        PlanItemUpserter.call(
          service_id: service_id,
          item_key: fetch_required(item, "item_key", path),
          title: fetch_required(item, "title", path),
          priority: (item["priority"] || :medium).to_sym,
          category: item["category"],
          kpi_hypothesis: item["kpi_hypothesis"],
          notes: item["notes"],
          status: (item["status"] || :todo).to_sym
        )
      end

      items.size
    end

    def fetch_required(item, key, path)
      value = item[key]
      raise ArgumentError, "#{key} missing in #{path}: #{item.inspect}" if value.to_s.strip.empty?

      value
    end
  end
end
