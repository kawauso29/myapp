class LineNotifierService
  def notify_new_messages(messages)
    return if messages.empty?

    client = build_client
    text = build_message_text(messages)

    response = client.push_message(user_id, [{ type: "text", text: text }])

    unless response.is_a?(Net::HTTPOK)
      body = response.body rescue nil
      raise "LINE送信失敗: #{response.code} #{body}"
    end

    Rails.logger.info("[LineNotifierService] #{messages.size}件通知送信完了")
  end

  private

  def build_client
    Line::Bot::Client.new do |config|
      config.channel_secret = line_credentials[:channel_secret]
      config.channel_token  = line_credentials[:channel_token]
    end
  end

  def build_message_text(messages)
    lines = ["📬 Picroに#{messages.size}件の新着メッセージがあります\n"]
    messages.first(5).each do |msg|
      sender = msg[:sender_name].presence || "不明"
      title  = msg[:title].presence || "(件名なし)"
      lines << "・#{sender}「#{title}」"
    end
    lines << "\n#{BASE_URL}/members/messages/" if messages.size > 0
    lines.join("\n")
  end

  def user_id
    line_credentials[:user_id]
  end

  def line_credentials
    Rails.application.credentials.line!
  end

  BASE_URL = "https://picro.jp"
end
