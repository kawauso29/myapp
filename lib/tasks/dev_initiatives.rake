namespace :dev_initiatives do
  desc "docs/ai_sns_plan_status.yml の全 item を dev_initiatives テーブルに冪等インポートする"
  task import_from_yaml: :environment do
    require "yaml"

    yaml_path = Rails.root.join("docs/ai_sns_plan_status.yml")
    unless yaml_path.exist?
      puts "#{yaml_path} が見つかりません。スキップします。"
      next
    end

    data = YAML.safe_load(yaml_path.read, permitted_classes: [ Date ])
    items = data.dig("items") || {}

    priority_map = { "high" => :high, "medium" => :medium, "low" => :low }
    status_map   = { "todo" => :todo, "in_progress" => :in_progress, "done" => :done }

    imported = 0
    updated  = 0

    items.each do |item_key, attrs|
      next unless attrs.is_a?(Hash)

      priority = priority_map.fetch(attrs["priority"].to_s, :medium)
      status   = status_map.fetch(attrs["status"].to_s, :todo)

      started_at   = attrs["started_at"].presence && Time.parse(attrs["started_at"].to_s) rescue nil
      completed_at = attrs["completed_at"].presence && Time.parse(attrs["completed_at"].to_s) rescue nil

      record = DevInitiative.find_or_initialize_by(item_key: item_key)
      existed = record.persisted?

      record.assign_attributes(
        title:          attrs["title"].to_s,
        category:       attrs["category"].to_s.presence,
        priority:       priority,
        status:         status,
        kpi_hypothesis: attrs["kpi_hypothesis"].to_s.presence,
        kpi_result:     attrs["kpi_result"].to_s.presence,
        pr_branch:      attrs["pr_branch"].to_s.presence,
        notes:          attrs["notes"].to_s.presence,
        started_at:     started_at,
        completed_at:   completed_at
      )
      record.save!

      if existed
        updated += 1
        puts "  更新: [#{item_key}] #{attrs['title']}"
      else
        imported += 1
        puts "  追加: [#{item_key}] #{attrs['title']}"
      end
    end

    puts "\n完了: 新規 #{imported} 件追加 / #{updated} 件更新"
  end
end
