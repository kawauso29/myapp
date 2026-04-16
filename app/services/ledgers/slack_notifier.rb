require "net/http"
require "json"

module Ledgers
  class SlackNotifier
    LEDGER_WEBHOOK_ENV = "SLACK_WEBHOOK_URL_LEDGER".freeze
    FALLBACK_WEBHOOK_ENV = "SLACK_WEBHOOK_URL".freeze

    def self.notify(payload)
      new(payload).notify
    end

    def initialize(payload)
      @payload = payload
    end

    def notify
      webhook_url = ENV[LEDGER_WEBHOOK_ENV].presence || ENV[FALLBACK_WEBHOOK_ENV].presence
      unless webhook_url.present?
        Rails.logger.warn("[Ledgers::SlackNotifier] webhook URL is not configured. skip notification.")
        return
      end

      post_to_slack(webhook_url:, body: { text: format_text })
    rescue StandardError => e
      Rails.logger.error("[Ledgers::SlackNotifier] failed to notify slack: #{e.class}: #{e.message}")
    end

    private

    attr_reader :payload

    def format_text
      operation = payload[:operation] || payload["operation"] || "unknown"
      tickets_created = counts[:tickets_created] || counts["tickets_created"] || 0
      held_items = counts[:held_items] || counts["held_items"] || 0
      overdue_marked = payload[:overdue_marked] || payload["overdue_marked"] || 0

      "[ops-ledger] operation=#{operation} tickets_created=#{tickets_created} held_items=#{held_items} overdue_marked=#{overdue_marked}"
    end

    def counts
      payload[:counts] || payload["counts"] || {}
    end

    def post_to_slack(webhook_url:, body:)
      uri = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      response = http.request(request)
      return if response.is_a?(Net::HTTPSuccess)

      Rails.logger.error("[Ledgers::SlackNotifier] HTTP error: #{response.code} #{response.body}")
    end
  end
end
