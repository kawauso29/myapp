require "net/http"
require "json"
require "base64"

class GithubPrService
  GITHUB_API_BASE = "https://api.github.com"
  REPO = "kawauso29/myapp"
  BASE_BRANCH = "main"
  SUCCESSFUL_CHECK_CONCLUSIONS = %w[success neutral skipped].freeze
  FAILURE_CHECK_CONCLUSIONS = %w[failure timed_out cancelled action_required startup_failure stale].freeze
  SUCCESSFUL_COMMIT_STATES = %w[success].freeze
  FAILURE_COMMIT_STATES = %w[error failure].freeze

  def self.create_pr(title:, body:, branch_prefix: "copilot/ai-sns", draft: false, path_prefix: "docs/ai_sns_proposals")
    new.create_pr(title: title, body: body, branch_prefix: branch_prefix, draft: draft, path_prefix: path_prefix)
  end

  def self.fetch_ci_status(pr_number:)
    new.fetch_ci_status(pr_number: pr_number)
  end

  def self.merge_pr(pr_number:, sha:, commit_title: nil, merge_method: "squash")
    new.merge_pr(pr_number: pr_number, sha: sha, commit_title: commit_title, merge_method: merge_method)
  end

  def create_pr(title:, body:, branch_prefix:, draft: false, path_prefix: "docs/ai_sns_proposals")
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
    create_placeholder_commit(token, branch_name: branch_name, title: title, body: body, path_prefix: path_prefix)
    create_pr_request(token, title: title, body: body, branch_name: branch_name, draft: draft)
  rescue => e
    Rails.logger.error("[GithubPrService] PR作成エラー: #{e.class} #{e.message}")
    nil
  end

  def fetch_ci_status(pr_number:)
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      Rails.logger.warn("[GithubPrService] DEPLOY_TOKEN が未設定のためCI状態取得をスキップします")
      return nil
    end

    pr = fetch_pull_request(token, pr_number)
    return nil unless pr

    head_sha = pr.dig("head", "sha")
    return nil if head_sha.blank?

    check_runs = fetch_check_runs(token, head_sha)
    statuses = fetch_commit_statuses(token, head_sha)

    summarize_ci_status(pr_number: pr_number, pr: pr, head_sha: head_sha, check_runs: check_runs, statuses: statuses)
  rescue => e
    Rails.logger.error("[GithubPrService] CI状態取得エラー: #{e.class} #{e.message}")
    nil
  end

  def merge_pr(pr_number:, sha:, commit_title: nil, merge_method: "squash")
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      Rails.logger.warn("[GithubPrService] DEPLOY_TOKEN が未設定のためPR mergeをスキップします")
      return nil
    end

    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/pulls/#{pr_number}/merge")
    res = request(:put, uri, token, {
      sha: sha,
      commit_title: commit_title,
      merge_method: merge_method
    }.compact)

    if res.is_a?(Net::HTTPOK)
      JSON.parse(res.body)
    else
      Rails.logger.error("[GithubPrService] PR merge失敗 (#{res.code}): #{res.body}")
      parsed_error_response(res)
    end
  rescue => e
    Rails.logger.error("[GithubPrService] PR mergeエラー: #{e.class} #{e.message}")
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

  def create_placeholder_commit(token, branch_name:, title:, body:, path_prefix:)
    sanitized_branch_name = branch_name.gsub("/", "-")
    path = "#{path_prefix}/#{sanitized_branch_name}.md"
    content = "# #{title}\n\n#{body}\n"
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/contents/#{path}")
    request(:put, uri, token,
      message: "proposal: #{title}",
      content: Base64.strict_encode64(content),
      branch: branch_name)
  end

  def create_pr_request(token, title:, body:, branch_name:, draft:)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/pulls")
    res = request(:post, uri, token,
      title: title,
      body: body,
      head: branch_name,
      base: BASE_BRANCH,
      draft: draft)

    if res.is_a?(Net::HTTPCreated)
      parsed = JSON.parse(res.body)
      Rails.logger.info("[GithubPrService] PR created: ##{parsed['number']} #{parsed['html_url']}")
      parsed
    else
      Rails.logger.error("[GithubPrService] PR作成失敗 (#{res.code}): #{res.body}")
      nil
    end
  end

  def fetch_pull_request(token, pr_number)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/pulls/#{pr_number}")
    res = request(:get, uri, token)
    return nil unless res.is_a?(Net::HTTPOK)

    JSON.parse(res.body)
  end

  def fetch_check_runs(token, sha)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/commits/#{sha}/check-runs")
    res = request(:get, uri, token)
    return [] unless res.is_a?(Net::HTTPOK)

    JSON.parse(res.body).fetch("check_runs", [])
  end

  def fetch_commit_statuses(token, sha)
    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/commits/#{sha}/status")
    res = request(:get, uri, token)
    return { "state" => nil, "statuses" => [] } unless res.is_a?(Net::HTTPOK)

    JSON.parse(res.body)
  end

  def summarize_ci_status(pr_number:, pr:, head_sha:, check_runs:, statuses:)
    normalized_check_runs = Array(check_runs).map do |check_run|
      {
        "name" => check_run["name"],
        "status" => check_run["status"],
        "conclusion" => check_run["conclusion"],
        "details_url" => check_run["details_url"]
      }
    end
    normalized_statuses = Array(statuses["statuses"]).map do |status|
      {
        "context" => status["context"],
        "state" => status["state"],
        "target_url" => status["target_url"]
      }
    end

    aggregate_status =
      if pending_ci?(normalized_check_runs, normalized_statuses)
        "pending"
      elsif failed_ci?(normalized_check_runs, normalized_statuses)
        "failure"
      elsif observed_ci?(normalized_check_runs, normalized_statuses, statuses["state"])
        "success"
      else
        "pending"
      end

    {
      "pr_number" => pr_number.to_i,
      "pr_url" => pr["html_url"],
      "head_sha" => head_sha,
      "state" => pr["state"],
      "draft" => pr["draft"],
      "status" => aggregate_status,
      "conclusion" => aggregate_status == "pending" ? "pending" : aggregate_status,
      "failed_checks" => failed_checks_from(normalized_check_runs, normalized_statuses),
      "check_runs" => normalized_check_runs,
      "statuses" => normalized_statuses
    }
  end

  def pending_ci?(check_runs, statuses)
    check_runs.any? { |check_run| check_run["status"] != "completed" } ||
      statuses.any? { |status| status["state"] == "pending" }
  end

  def failed_ci?(check_runs, statuses)
    check_runs.any? do |check_run|
      check_run["status"] == "completed" && FAILURE_CHECK_CONCLUSIONS.include?(check_run["conclusion"])
    end || statuses.any? { |status| FAILURE_COMMIT_STATES.include?(status["state"]) }
  end

  def observed_ci?(check_runs, statuses, combined_state)
    check_runs.any? || statuses.any? || SUCCESSFUL_COMMIT_STATES.include?(combined_state)
  end

  def failed_checks_from(check_runs, statuses)
    failed_check_runs = check_runs.filter_map do |check_run|
      check_run["name"] if check_run["status"] == "completed" && FAILURE_CHECK_CONCLUSIONS.include?(check_run["conclusion"])
    end
    failed_statuses = statuses.filter_map do |status|
      status["context"] if FAILURE_COMMIT_STATES.include?(status["state"])
    end

    (failed_check_runs + failed_statuses).uniq
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

  def parsed_error_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    { "message" => response.body, "status" => response.code }
  end
end
