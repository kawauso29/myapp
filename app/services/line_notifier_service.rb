require "line/bot"

class LineNotifierService
  BASE_URL = "https://picro.jp"

  def notify_new_messages(messages)
    return if messages.empty?

    text = build_message_text(messages)
    response = send_line_message(text)
    Rails.logger.info("[LineNotifierService] #{send_method_label}: code=#{response.code} body=#{response.body}")
    unless response.code == "200"
      raise "LINE #{send_method_label}失敗: code=#{response.code} body=#{response.body}"
    end

    Rails.logger.info("[LineNotifierService] #{messages.size}件通知送信完了（#{send_method_label}）")
  end

  private

  def send_line_message(text)
    message_payload = [{ type: "text", text: text }]

    friend_ids = Array(line_credentials[:friend_ids]).select(&:present?)
    user_id    = line_credentials[:user_id].presence

    if friend_ids.any?
      @send_method = :multicast
      body, status, = client.multicast_with_http_info(multicast_request: { to: friend_ids, messages: message_payload })
    elsif user_id.present?
      @send_method = :push
      body, status, = client.push_message_with_http_info(push_message_request: { to: user_id, messages: message_payload })
    else
      @send_method = :broadcast
      body, status, = client.broadcast_with_http_info(broadcast_request: { messages: message_payload })
    end

    Struct.new(:code, :body).new(status.to_s, body.to_s)
  end

  def client
    @client ||= Line::Bot::V2::MessagingApi::ApiClient.new(channel_access_token: line_credentials[:channel_token])
  end

  def send_method_label
    case @send_method
    when :multicast then "multicast（#{Array(line_credentials[:friend_ids]).size}人）"
    when :push      then "push_message"
    else                 "broadcast"
    end
  end

  def build_message_text(messages)
    lines = ["📬 Picroに#{messages.size}件の新着メッセージがあります\n"]
    messages.first(5).each do |msg|
      title   = msg[:title].presence || "(件名なし)"
      preview = msg[:preview].presence
      lines << "・#{title}"
      lines << preview if preview
    end
    lines << "\n#{BASE_URL}/sports/amitie/messages/inbox"
    lines.join("\n")
  end

  def line_credentials
    @line_credentials ||= Rails.application.credentials.line!
  end
end
