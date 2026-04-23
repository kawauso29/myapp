require "net/http"
require "json"

class GithubIssueService
  GITHUB_API_BASE = "https://api.github.com"
  REPO = "kawauso29/myapp"

  def self.create_issue(title:, body:, labels: [])
    new.create_issue(title: title, body: body, labels: labels)
  end

  def create_issue(title:, body:, labels: [])
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      Rails.logger.warn("[GithubIssueService] DEPLOY_TOKEN が未設定のためIssue作成をスキップします")
      return nil
    end

    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/issues")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"

    payload = { title: title, body: body }
    payload[:labels] = labels if labels.any?
    req.body = payload.to_json

    res = http.request(req)
    if res.is_a?(Net::HTTPCreated)
      parsed = JSON.parse(res.body)
      Rails.logger.info("[GithubIssueService] Issue created: ##{parsed['number']} #{parsed['html_url']}")
      parsed
    else
      Rails.logger.error("[GithubIssueService] Issue作成失敗 (#{res.code}): #{res.body}")
      nil
    end
  rescue => e
    Rails.logger.error("[GithubIssueService] Issue作成エラー: #{e.class} #{e.message}")
    nil
  end

  def self.create_comment(issue_number:, body:)
    new.create_comment(issue_number: issue_number, body: body)
  end

  def create_comment(issue_number:, body:)
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      Rails.logger.warn("[GithubIssueService] DEPLOY_TOKEN が未設定のためコメント投稿をスキップします")
      return nil
    end

    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/issues/#{issue_number}/comments")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = { body: body }.to_json

    res = http.request(req)
    if res.is_a?(Net::HTTPCreated)
      parsed = JSON.parse(res.body)
      Rails.logger.info("[GithubIssueService] Comment posted to Issue ##{issue_number}: #{parsed['html_url']}")
      parsed
    else
      Rails.logger.error("[GithubIssueService] コメント投稿失敗 (#{res.code}): #{res.body}")
      nil
    end
  rescue => e
    Rails.logger.error("[GithubIssueService] コメント投稿エラー: #{e.class} #{e.message}")
    nil
  end

  def self.close_issue(issue_number:, comment: nil)
    new.close_issue(issue_number: issue_number, comment: comment)
  end

  def close_issue(issue_number:, comment: nil)
    token = ENV["DEPLOY_TOKEN"]
    unless token.present?
      Rails.logger.warn("[GithubIssueService] DEPLOY_TOKEN が未設定のためIssueクローズをスキップします")
      return nil
    end

    if comment.present?
      create_comment(issue_number: issue_number, body: comment)
    end

    uri = URI("#{GITHUB_API_BASE}/repos/#{REPO}/issues/#{issue_number}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Patch.new(uri.request_uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/vnd.github+json"
    req["X-GitHub-Api-Version"] = "2022-11-28"
    req["Content-Type"] = "application/json"
    req.body = { state: "closed" }.to_json

    res = http.request(req)
    if res.is_a?(Net::HTTPSuccess)
      parsed = JSON.parse(res.body)
      Rails.logger.info("[GithubIssueService] Issue closed: ##{issue_number}")
      parsed
    else
      Rails.logger.error("[GithubIssueService] Issueクローズ失敗 (#{res.code}): #{res.body}")
      nil
    end
  rescue => e
    Rails.logger.error("[GithubIssueService] Issueクローズエラー: #{e.class} #{e.message}")
    nil
  end
end
