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

    friend_ids = line_credentials[:friend_ids].presence
    user_id    = line_credentials[:user_id].presence

    if friend_ids.is_a?(Array) && friend_ids.any?
      @send_method = :multicast
      client.multicast(friend_ids, message_payload)
    elsif user_id.present?
      @send_method = :push
      client.push_message(user_id, message_payload)
    else
      @send_method = :broadcast
      client.broadcast(message_payload)
    end
  end

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = line_credentials[:channel_secret]
      config.channel_token  = line_credentials[:channel_token]
    end
  end

  def send_method_label
    case @send_method
    when :multicast then "multicast（#{line_credentials[:friend_ids].size}人）"
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
