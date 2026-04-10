require "openssl"

class SlackEventsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_signature, only: [ :events ]

  # デバッグ用: ブラウザで GET /slack/test を叩いて動作確認
  def test
    results = {
      env: {
        SLACK_BOT_TOKEN: ENV["SLACK_BOT_TOKEN"].present? ? "set (#{ENV['SLACK_BOT_TOKEN'].to_s[0..10]}...)" : "NOT SET",
        SLACK_SIGNING_SECRET: ENV["SLACK_SIGNING_SECRET"].present? ? "set" : "NOT SET",
        SLACK_ERROR_CHANNEL_ID: ENV["SLACK_ERROR_CHANNEL_ID"].presence || "NOT SET",
        SLACK_CLAUDE_CHANNEL_ID: ENV["SLACK_CLAUDE_CHANNEL_ID"].presence || "NOT SET",
        SLACK_CLAUDE_MEMBER_ID: ENV["SLACK_CLAUDE_MEMBER_ID"].presence || "NOT SET"
      }
    }

    if ENV["SLACK_BOT_TOKEN"].present? && ENV["SLACK_CLAUDE_CHANNEL_ID"].present?
      job = SlackForwardToClaudeJob.new
      job.perform(
        text: "🔧 テスト送信: Slack転送システムの動作確認",
        channel: ENV["SLACK_ERROR_CHANNEL_ID"] || "test",
        user: "test",
        ts: Time.current.to_f.to_s
      )
      results[:test_message] = "Claudeチャネルへの送信を試みました"
    else
      results[:test_message] = "環境変数が不足しているため送信できません"
    end

    render json: results
  end

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
        text: extract_full_text(event),
        channel: event["channel"],
        user: event["user"],
        ts: event["ts"]
      )
    end

    head :ok
  end

  ERROR_KEYWORDS = %w[
    error Error ERROR exception Exception
    500 NoMethodError RuntimeError TypeError
    FATAL fatal crashed failed failure
    CI\ failed
  ].freeze

  private

  def verify_slack_signature
    timestamp = request.headers["X-Slack-Request-Timestamp"]
    signature = request.headers["X-Slack-Signature"]

    unless timestamp.present? && signature.present?
      return head :unauthorized
    end

    # リプレイ攻撃防止（5分以上古いリクエストを拒否）
    if (Time.current.to_i - timestamp.to_i).abs > 300
      return head :unauthorized
    end

    sig_basestring = "v0:#{timestamp}:#{request.raw_post}"
    expected = "v0=#{OpenSSL::HMAC.hexdigest("SHA256", ENV["SLACK_SIGNING_SECRET"].to_s, sig_basestring)}"

    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      head :unauthorized
    end
  end

  def forwardable_message?(event)
    return false if event.nil?
    return false unless event["type"] == "message"
    # 編集・削除・参加退出イベントは無視（bot_messageは通す）
    ignored = %w[message_changed message_deleted channel_join channel_leave]
    return false if ignored.include?(event["subtype"])
    # エラー監視チャネルのメッセージのみ対象
    return false unless event["channel"] == ENV["SLACK_ERROR_CHANNEL_ID"]
    # デプロイ通知は除外（「デプロイ」テキストでフィルタ）
    full_text = extract_full_text(event)
    return false if full_text.include?("デプロイ")
    # attachments内も含めてキーワード検索（Incoming Webhookはtextが空でattachmentsに内容が入る）
    ERROR_KEYWORDS.any? { |kw| full_text.include?(kw) }
  end

  # event["text"]はIncoming Webhook経由のbotメッセージでは空になるため
  # attachments内とblocks内のテキストも結合して返す
  def extract_full_text(event)
    parts = [ event["text"].to_s ]

    # attachmentsからテキストを抽出
    Array(event["attachments"]).each do |att|
      parts << att["pretext"].to_s
      parts << att["text"].to_s
      Array(att["fields"]).each { |f| parts << f["value"].to_s }
    end

    # blocks（Blocks API）からテキストを抽出
    Array(event["blocks"]).each do |block|
      # section, header, context などのブロックからテキストを抽出
      if block["text"].is_a?(Hash)
        parts << block["text"]["text"].to_s
      end
      # fields からも抽出
      Array(block["fields"]).each do |field|
        parts << field["text"].to_s if field.is_a?(Hash)
      end
      # elements（context blockなど）からも抽出
      Array(block["elements"]).each do |elem|
        parts << elem["text"].to_s if elem.is_a?(Hash) && elem["text"].present?
      end
    end

    parts.join(" ")
  end
end
