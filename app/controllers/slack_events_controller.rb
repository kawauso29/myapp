require "openssl"

class SlackEventsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_signature

  def events
    payload = JSON.parse(request.raw_post)

    # URL verification challenge (Slack App設定時に一度だけ呼ばれる)
    if payload["type"] == "url_verification"
      render json: { challenge: payload["challenge"] }
      return
    end

    event = payload["event"]
    if forwardable_message?(event)
      SlackForwardToClaudeJob.perform_later(
        text: event["text"],
        channel: event["channel"],
        user: event["user"],
        ts: event["ts"]
      )
    end

    head :ok
  end

  private

  def verify_slack_signature
    timestamp = request.headers["X-Slack-Request-Timestamp"]
    signature = request.headers["X-Slack-Signature"]

    unless timestamp.present? && signature.present?
      head :unauthorized and return
    end

    # リプレイ攻撃防止（5分以上古いリクエストを拒否）
    if (Time.now.to_i - timestamp.to_i).abs > 300
      head :unauthorized and return
    end

    sig_basestring = "v0:#{timestamp}:#{request.raw_post}"
    expected = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", ENV["SLACK_SIGNING_SECRET"].to_s, sig_basestring)

    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      head :unauthorized and return
    end
  end

  ERROR_KEYWORDS = %w[
    error Error ERROR exception Exception
    500 NoMethodError RuntimeError TypeError
    FATAL fatal crashed failed
  ].freeze

  def forwardable_message?(event)
    return false if event.nil?
    return false unless event["type"] == "message"
    # botのメッセージは無視（デプロイ通知・転送ループ防止）
    return false if event["bot_id"].present? || event["subtype"].present?
    # エラー監視チャネルのメッセージのみ対象
    return false unless event["channel"] == ENV["SLACK_ERROR_CHANNEL_ID"]
    # エラーキーワードを含むメッセージのみ転送
    text = event["text"].to_s
    ERROR_KEYWORDS.any? { |kw| text.include?(kw) }
  end
end
