require "net/http"
require "json"

class SlackNotifierService
  LEGACY_WEBHOOK_URL = ENV["SLACK_WEBHOOK_URL"]
  SERVICE_WEBHOOK_METADATA_KEY = "slack_webhook_url".freeze

  WEBHOOK_URLS = {
    error: ENV["SLACK_WEBHOOK_URL_ERROR"],
    jobs:  ENV["SLACK_WEBHOOK_URL_JOBS"]
  }.freeze

  COLORS = {
    success: "#2eb886",
    danger:  "#e01e5a",
    warning: "#ecb22e",
    info:    "#36c5f0"
  }.freeze

  def self.notify(text:, color: :info, fields: [], channel: :error, service_id: nil)
    channel_key = channel.to_sym
    webhook_url = resolve_webhook_url(channel_key, service_id: service_id)
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

  def self.resolve_webhook_url(channel_key, service_id: nil)
    if service_id.present?
      service_webhook = service_webhook_url_for(service_id)
      return service_webhook if service_webhook.present?
    end

    return WEBHOOK_URLS[:error].presence || LEGACY_WEBHOOK_URL if channel_key == :error

    webhook_url = WEBHOOK_URLS[channel_key].presence
    return webhook_url if webhook_url.present?

    Rails.logger.warn("[Slack] channel=#{channel_key} のWebhookが未設定のため通知をスキップしました")
    nil
  end

  def self.service_webhook_url_for(service_id)
    ledger = ServiceLedger.find_by(service_id: service_id)
    return nil unless ledger

    webhook_url = ledger.metadata[SERVICE_WEBHOOK_METADATA_KEY].to_s.strip
    return nil if webhook_url.blank?

    uri = URI.parse(webhook_url)
    return webhook_url if uri.is_a?(URI::HTTPS) && uri.host.present?

    Rails.logger.warn("[Slack] service_id=#{service_id} のWebhookがhttpsではないため無視しました")
    nil
  rescue URI::InvalidURIError
    Rails.logger.warn("[Slack] service_id=#{service_id} のWebhookが不正な形式のため無視しました")
    nil
  rescue => e
    Rails.logger.warn("[Slack] service_id=#{service_id} のWebhook解決に失敗: #{e.class}: #{e.message}")
    nil
  end

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
