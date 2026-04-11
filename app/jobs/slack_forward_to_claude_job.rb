class SlackForwardToClaudeJob < ApplicationJob
  queue_as :default

  def perform(text:, channel:, user:, ts: nil)
    claude_channel   = ENV["SLACK_CLAUDE_CHANNEL_ID"]
    error_channel    = ENV["SLACK_ERROR_CHANNEL_ID"]

    return unless claude_channel.present?

    github_mention = ENV["SLACK_GITHUB_MEMBER_ID"].present? ? "<@#{ENV["SLACK_GITHUB_MEMBER_ID"]}>" : "@GitHub"

    # ts が渡された場合のみ元メッセージへのリンクを生成（スラッシュコマンド経由の場合はリンクなし）
    original_link = ts.present? ? build_message_link(error_channel, ts) : nil

    message_parts = [ "#{github_mention} 以下のエラーを修正してください:" ]
    message_parts << original_link if original_link
    message_parts << "```\n#{text}\n```"

    # SLACK_THREAD_TS が設定されている場合はそのスレッドに返信する
    thread_ts = ENV["SLACK_THREAD_TS"].presence
    post_message(channel: claude_channel, text: message_parts.join("\n"), thread_ts: thread_ts)
  end

  private

  def build_message_link(channel, ts)
    # Slackのメッセージリンク形式: https://slack.com/archives/CHANNEL/pTIMESTAMP
    ts_escaped = ts.to_s.sub(".", "")
    "https://slack.com/archives/#{channel}/p#{ts_escaped}"
  end

  def post_message(channel:, text:, thread_ts: nil)
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
    payload = { channel: channel, text: text, link_names: true }
    payload[:thread_ts] = thread_ts if thread_ts.present?
    request.body = payload.to_json

    response = http.request(request)
    body = JSON.parse(response.body)

    unless body["ok"]
      Rails.logger.error("[SlackForwardToClaudeJob] chat.postMessage失敗: #{body['error']}")
    end
  rescue => e
    Rails.logger.error("[SlackForwardToClaudeJob] エラー: #{e.message}")
  end
end
