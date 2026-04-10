require "net/http"
require "json"

class SlackForwardToClaudeJob < ApplicationJob
  queue_as :default

  def perform(text:, channel:, user:, ts:)
    claude_member_id = ENV["SLACK_CLAUDE_MEMBER_ID"]
    claude_channel   = ENV["SLACK_CLAUDE_CHANNEL_ID"]
    error_channel    = ENV["SLACK_ERROR_CHANNEL_ID"]

    return unless claude_channel.present? && claude_member_id.present?

    # 元メッセージへのリンクを生成
    original_link = build_message_link(error_channel, ts)

    message = <<~TEXT
      <@#{claude_member_id}> 以下のエラーを修正してください:
      #{original_link}
      ```
      #{text}
      ```
    TEXT

    post_message(channel: claude_channel, text: message.strip)
  end

  private

  def build_message_link(channel, ts)
    # Slackのメッセージリンク形式: https://slack.com/archives/CHANNEL/pTIMESTAMP
    ts_escaped = ts.to_s.sub(".", "")
    "https://slack.com/archives/#{channel}/p#{ts_escaped}"
  end

  def post_message(channel:, text:)
    token = ENV["SLACK_BOT_TOKEN"]
    return unless token.present?

    uri = URI("https://slack.com/api/chat.postMessage")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{token}"
    request.body = { channel: channel, text: text }.to_json

    response = http.request(request)
    body = JSON.parse(response.body)

    unless body["ok"]
      Rails.logger.error("[SlackForwardToClaudeJob] chat.postMessage失敗: #{body['error']}")
    end
  rescue => e
    Rails.logger.error("[SlackForwardToClaudeJob] エラー: #{e.message}")
  end
end
