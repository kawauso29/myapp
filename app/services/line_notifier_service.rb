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

    # broadcast: LINE bot を友達追加しているユーザー全員へ
    response = client.broadcast([ { type: "text", text: text } ])
    raise "LINE broadcast失敗: #{response.code}" unless response.code == "200"

    # multicast: LINEログインしたアプリユーザー全員へ（bot未追加でも届く）
    line_uids = User.where(provider: "line").pluck(:uid).compact
    if line_uids.any?
      response2 = client.multicast(line_uids, [ { type: "text", text: text } ])
      if response2.code == "200"
        Rails.logger.info("[LineNotifierService] multicast #{line_uids.size}人へ送信完了")
      else
        Rails.logger.warn("[LineNotifierService] multicast失敗: #{response2.code}")
      end
    end

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
