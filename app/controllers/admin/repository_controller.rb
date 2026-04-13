require "net/http"

class Admin::RepositoryController < Admin::BaseController
  def index
    @stats = {
      failed_jobs: safe_count { SolidQueue::FailedExecution.count },
      finished_jobs: safe_count { SolidQueue::Job.where.not(finished_at: nil).count },
      picro_today: safe_count { PicroMessage.where("received_at >= ?", Time.current.beginning_of_day).count },
      trade_decisions_today: safe_count { TradeDecision.where("created_at >= ?", Time.current.beginning_of_day).count },
      snapshots: safe_count { MarketSnapshot.count }
    }

    @recent_failed_jobs = SolidQueue::FailedExecution
      .includes(:job)
      .order(created_at: :desc)
      .limit(10)
  rescue => e
    Rails.logger.warn("Admin::RepositoryController#index failed: #{e.message}")
    @stats = { failed_jobs: 0, finished_jobs: 0, picro_today: 0, trade_decisions_today: 0, snapshots: 0 }
    @recent_failed_jobs = []
  ensure
    @github_actions_migration = Admin::ProjectProgressService.github_actions_migration
  end

  def sync_env
    token = ENV["DEPLOY_TOKEN"]
    return redirect_to admin_root_path, alert: "DEPLOY_TOKEN が設定されていません" unless token.present?

    res = github_dispatch_request(
      token: token,
      workflow: "deploy.yml",
      body: { ref: "main", inputs: { reason: "Admin panel sync" } }.to_json
    )

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
    return redirect_to admin_root_path, alert: "DEPLOY_TOKEN が設定されていません" unless token.present?

    res = github_dispatch_request(
      token: token,
      workflow: "db_snapshot.yml",
      body: { ref: "main" }.to_json
    )

    if res.code == "204"
      redirect_to admin_root_path, notice: "DBスナップショットを開始しました。db-snapshots ブランチに保存されます。"
    else
      redirect_to admin_root_path, alert: "スナップショット起動失敗 (#{res.code}): #{res.body}"
    end
  rescue => e
    redirect_to admin_root_path, alert: "エラー: #{e.message}"
  end

  private

  def safe_count
    yield
  rescue
    0
  end

  def github_dispatch_request(token:, workflow:, body:)
    uri = URI("https://api.github.com/repos/kawauso29/myapp/actions/workflows/#{workflow}/dispatches")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = body

    http.request(req)
  end
end
