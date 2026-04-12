require "net/http"
require "yaml"

class Admin::DashboardController < Admin::BaseController
  def index
    # 直近スナップショット
    @latest_snapshot  = MarketSnapshot.recent.first
    @recent_snapshots = MarketSnapshot.recent.limit(10)

    # 直近の売買判断
    @recent_decisions = TradeDecision
      .includes(:market_snapshot)
      .order(created_at: :desc)
      .limit(20)

    # 直近の執行結果
    @recent_results = TradeResult
      .includes(trade_decision: :market_snapshot)
      .order(created_at: :desc)
      .limit(10)

    # 今日の統計
    today = Time.current.beginning_of_day
    @today_stats = {
      total:   TradeDecision.where("created_at >= ?", today).count,
      execute: TradeDecision.where("created_at >= ?", today).executed.count,
      skip:    TradeDecision.where("created_at >= ?", today).skipped.count,
      wins:    TradeResult.joins(trade_decision: :market_snapshot)
                          .where("trade_results.created_at >= ?", today)
                          .wins.count,
      losses:  TradeResult.joins(trade_decision: :market_snapshot)
                          .where("trade_results.created_at >= ?", today)
                          .losses.count,
      pnl:     TradeResult.where("created_at >= ?", today).sum(:profit_loss).to_f.round(2)
    }

    # 直近エージェント判断（最新スナップショット分）
    @latest_judgments = @latest_snapshot&.agent_judgments&.order(:agent_type) || []

    # 未レビューの分析レポート
    @pending_reports = AnalysisReport.pending_review.order(created_at: :desc)

    # 累計損益
    @total_pnl = TradeResult.sum(:profit_loss).to_f.round(2)

    # AI SNS 改良計画の進捗
    @ai_sns_plan_stats = Admin::AiSnsPlanService.stats
    @ai_sns_plan_next  = Admin::AiSnsPlanService.next_item
    @ai_sns_plan_items = Admin::AiSnsPlanService.items_by_priority
  end

  def sync_env
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      redirect_to admin_root_path, alert: "DEPLOY_TOKEN が設定されていません"
      return
    end

    uri = URI("https://api.github.com/repos/kawauso29/myapp/actions/workflows/deploy.yml/dispatches")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = { ref: "main", inputs: { reason: "Admin panel sync" } }.to_json

    res = http.request(req)
    if res.code == "204"
      redirect_to admin_root_path, notice: "デプロイを開始しました。GitHub Actions を確認してください。"
    else
      redirect_to admin_root_path, alert: "デプロイ起動失敗 (#{res.code}): #{res.body}"
    end
  rescue => e
    redirect_to admin_root_path, alert: "エラー: #{e.message}"
  end

  def trigger_db_snapshot
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      redirect_to admin_root_path, alert: "DEPLOY_TOKEN が設定されていません"
      return
    end

    uri = URI("https://api.github.com/repos/kawauso29/myapp/actions/workflows/db_snapshot.yml/dispatches")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = { ref: "main" }.to_json

    res = http.request(req)
    if res.code == "204"
      redirect_to admin_root_path, notice: "DBスナップショットを開始しました。db-snapshots ブランチに保存されます。"
    else
      redirect_to admin_root_path, alert: "スナップショット起動失敗 (#{res.code}): #{res.body}"
    end
  rescue => e
    redirect_to admin_root_path, alert: "エラー: #{e.message}"
  end

  def trigger_ai_sns_plan
    token = ENV["GITHUB_DEPLOY_TOKEN"]
    unless token.present?
      redirect_to admin_root_path, alert: "GITHUB_DEPLOY_TOKEN が設定されていません"
      return
    end

    item_id = params[:item_id].presence || ""

    uri = URI("https://api.github.com/repos/kawauso29/myapp/actions/workflows/ai_sns_plan.yml/dispatches")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = { ref: "main", inputs: { item_id: item_id } }.to_json

    res = http.request(req)
    if res.code == "204"
      msg = item_id.present? ? "[#{item_id}] の実装依頼を Copilot に送りました。" : "次の優先項目の実装依頼を Copilot に送りました。"
      redirect_to admin_root_path, notice: "#{msg} GitHub Actions を確認してください。"
    else
      redirect_to admin_root_path, alert: "ワークフロー起動失敗 (#{res.code}): #{res.body}"
    end
  rescue => e
    redirect_to admin_root_path, alert: "エラー: #{e.message}"
  end
end
