class PicroCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[PicroCheckJob] 開始")

    # 1. Picroからメッセージ一覧を取得
    result = PicroScraperService.new.call
    unless result.success
      Rails.logger.error("[PicroCheckJob] スクレイピング失敗: #{result.error}")
      return
    end

    fetched = result.messages
    return if fetched.empty?

    # 2. 未登録のメッセージIDを特定
    fetched_ids = fetched.map { |m| m[:message_id] }
    new_ids = PicroMessage.new_message_ids(fetched_ids)

    if new_ids.empty?
      Rails.logger.info("[PicroCheckJob] 新着なし")
      return
    end

    # 3. 新着メッセージをDBに保存
    new_messages = fetched.select { |m| new_ids.include?(m[:message_id]) }
    new_messages.each do |msg|
      PicroMessage.create!(
        message_id:  msg[:message_id],
        sender_name: msg[:sender_name],
        preview:     msg[:preview],
        received_at: msg[:received_at],
        notified:    false
      )
    end

    # 4. LINE通知
    LineNotifierService.new.notify_new_messages(new_messages)

    # 5. 通知済みフラグを更新
    PicroMessage.where(message_id: new_ids).update_all(notified: true)

    Rails.logger.info("[PicroCheckJob] 完了: #{new_messages.size}件の新着を通知")
  end
end
