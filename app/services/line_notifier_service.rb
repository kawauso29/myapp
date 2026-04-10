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

    recipient_ids = build_recipient_ids
    Rails.logger.info("[LineNotifierService] 送信先: #{recipient_ids.size}人 #{recipient_ids.inspect}")

    if recipient_ids.size >= 2
      # 2人以上: multicast（500件ずつ）
      recipient_ids.each_slice(500) do |batch|
        response = client.multicast(batch, [ { type: "text", text: text } ])
        unless response.code == "200"
          Rails.logger.error("[LineNotifierService] multicast失敗: code=#{response.code} body=#{response.body}")
        end
      end
      Rails.logger.info("[LineNotifierService] multicast #{recipient_ids.size}人へ送信")

    elsif recipient_ids.size == 1
      # 1人: push_message
      response = client.push_message(recipient_ids.first, [ { type: "text", text: text } ])
      unless response.code == "200"
        Rails.logger.error("[LineNotifierService] push_message失敗: code=#{response.code} body=#{response.body}")
        raise "LINE送信失敗: #{response.code}"
      end
      Rails.logger.info("[LineNotifierService] push_message #{recipient_ids.first}へ送信")

    else
      # IDリスト未設定: broadcast（botを友達追加した全員）
      Rails.logger.warn("[LineNotifierService] friend_ids未設定。broadcastで送信（bot友達追加者のみ届く）")
      response = client.broadcast([ { type: "text", text: text } ])
      unless response.code == "200"
        Rails.logger.error("[LineNotifierService] broadcast失敗: code=#{response.code} body=#{response.body}")
        raise "LINE broadcast失敗: #{response.code}"
      end
      Rails.logger.info("[LineNotifierService] broadcastで送信")
    end

    Rails.logger.info("[LineNotifierService] #{messages.size}件通知送信完了")
  end

  private

  def build_recipient_ids
    ids = []

    # credentials の friend_ids（友達全員のLINE User IDリスト）
    friend_ids = line_credentials[:friend_ids]
    ids += Array(friend_ids).compact.map(&:to_s).reject(&:empty?) if friend_ids

    # credentials の user_id（後方互換: 自分1人のID）
    single_id = line_credentials[:user_id]
    ids << single_id.to_s if single_id.present?

    ids.uniq
  end

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
