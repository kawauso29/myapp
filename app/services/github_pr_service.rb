require "net/http"
require "json"
require "base64"

class GithubPrService
  GITHUB_API_BASE = "https://api.github.com"
  REPO = "kawauso29/myapp"
  BASE_BRANCH = "main"

  def self.create_pr(title:, body:, branch_prefix: "copilot/ai-sns")
    new.create_pr(title: title, body: body, branch_prefix: branch_prefix)
  end

  def create_pr(title:, body:, branch_prefix:)
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      Rails.logger.warn("[GithubPrService] DEPLOY_TOKEN が未設定のためPR作成をスキップします")
      return nil
    end

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    branch_name = "#{branch_prefix}-#{timestamp}"

    main_sha = get_main_sha(token)
    return nil unless main_sha

    create_branch(token, branch_name: branch_name, sha: main_sha)
    create_placeholder_commit(token, branch_name: branch_name, title: title, body: body)
    create_pr_request(token, title: title, body: body, branch_name: branch_name)
  rescue => e
    Rails.logger.error("[GithubPrService] PR作成エラー: #{e.class} #{e.message}")
    nil
  end

  private

  def get_main_sha(token)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/git/ref/heads/#{BASE_BRANCH}")
    res = request(:get, uri, token)
    return nil unless res.is_a?(Net::HTTPOK)

    JSON.parse(res.body).dig("object", "sha")
  end

  def create_branch(token, branch_name:, sha:)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/git/refs")
    request(:post, uri, token, ref: "refs/heads/#{branch_name}", sha: sha)
  end

  def create_placeholder_commit(token, branch_name:, title:, body:)
    sanitized_branch_name = branch_name.gsub("/", "-")
    path = "docs/ai_sns_proposals/#{sanitized_branch_name}.md"
    content = "# #{title}\n\n#{body}\n"
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/contents/#{path}")
    request(:put, uri, token,
      message: "proposal: #{title}",
      content: Base64.strict_encode64(content),
      branch: branch_name)
  end

  def create_pr_request(token, title:, body:, branch_name:)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/pulls")
    res = request(:post, uri, token,
      title: title,
      body: body,
      head: branch_name,
      base: BASE_BRANCH,
      draft: false)

    if res.is_a?(Net::HTTPCreated)
      parsed = JSON.parse(res.body)
      Rails.logger.info("[GithubPrService] PR created: ##{parsed['number']} #{parsed['html_url']}")
      parsed
    else
      Rails.logger.error("[GithubPrService] PR作成失敗 (#{res.code}): #{res.body}")
      nil
    end
  end

  def request(method, uri, token, payload = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put }[method]
    req = req_class.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = payload.to_json if payload

    http.request(req)
  end
end
