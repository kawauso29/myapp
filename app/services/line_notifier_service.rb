require "line/bot"

class LineNotifierService
  BASE_URL = "https://picro.jp"

  def notify_new_messages(messages)
    return if messages.empty?

    text = build_message_text(messages)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = line_credentials[:channel_secret]
      config.channel_token  = line_credentials[:channel_token]
    end

    response = client.push_message(line_credentials[:user_id], [ { type: "text", text: text } ])
    raise "LINE送信失敗: #{response.code}" unless response.code == "200"

    Rails.logger.info("[LineNotifierService] #{messages.size}件通知送信完了")
  end

  private

  def build_message_text(messages)
    lines = [ "📬 Picroに#{messages.size}件の新着メッセージがあります\n" ]
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
    Rails.application.credentials.line!
  end
end
