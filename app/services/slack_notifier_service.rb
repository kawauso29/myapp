require "net/http"
require "json"

class SlackNotifierService
  # カテゴリ②: アプリエラー通知専用 Webhook（未設定時は SLACK_WEBHOOK_URL にフォールバック）
  WEBHOOK_URLS = {
    error: ENV["SLACK_WEBHOOK_URL_ERROR"] || ENV["SLACK_WEBHOOK_URL"],
    jobs:  ENV["SLACK_WEBHOOK_URL_JOBS"]  || ENV["SLACK_WEBHOOK_URL"]
  }.freeze

  COLORS = {
    success: "#2eb886",
    danger:  "#e01e5a",
    warning: "#ecb22e",
    info:    "#36c5f0"
  }.freeze

  def self.notify(text:, color: :info, fields: [], channel: :error)
    webhook_url = WEBHOOK_URLS[channel.to_sym] || WEBHOOK_URLS[:error]
    return unless webhook_url.present?
    new(webhook_url).send_message(text: text, color: color, fields: fields)
  rescue => e
    Rails.logger.error("[Slack] 通知の送信に失敗しました: #{e.message}")
  end

  def initialize(webhook_url = WEBHOOK_URLS[:error])
    @webhook_url = webhook_url
  end

  def send_message(text:, color: :info, fields: [])
    payload = build_payload(text: text, color: color, fields: fields)
    post_to_slack(payload)
  end

  private

  def build_payload(text:, color:, fields:)
    color_code = COLORS.fetch(color.to_sym, color.to_s)
    attachment = {
      color: color_code,
      text: text,
      footer: "myapp [#{Rails.env}]",
      ts: Time.current.to_i
    }
    attachment[:fields] = fields.map { |f| { title: f[:title], value: f[:value], short: f.fetch(:short, true) } } if fields.any?
    { attachments: [ attachment ] }
  end

  def post_to_slack(payload)
    uri = URI.parse(@webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("[Slack] HTTPエラー: #{response.code} #{response.body}")
    end
  end
end
