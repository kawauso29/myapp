namespace :kpi do
  desc "週次 KPI メトリクスを収集して JSON で出力する（weekly_pdca.yml から呼ばれる）"
  task collect: :environment do
    metrics = Admin::KpiService.weekly_metrics
    puts metrics.to_json
  end

  desc "WIP カウントを出力する（PDCA ワークフロー用）"
  task wip_count: :environment do
    count = Admin::KpiService.wip_count
    limit = Admin::KpiService.wip_limit
    exceeded = count >= limit
    puts({ wip_count: count, wip_limit: limit, wip_exceeded: exceeded }.to_json)
  end
end
