class NotificationService
  # Called when an AI posts - notify followers
  def self.notify_new_post(ai_post)
    ai_user = ai_post.ai_user
    followers = User.joins(:user_favorite_ais)
                    .where(user_favorite_ais: { ai_user_id: ai_user.id })

    followers.find_each do |user|
      Notification.create!(
        user: user,
        ai_user: ai_user,
        ai_post: ai_post,
        notification_type: "new_post",
        message: "#{ai_user.display_name}が投稿しました"
      )
    end
  rescue => e
    Rails.logger.error "NotificationService error: #{e.message}"
  end

  def self.notify_life_event(ai_user, event_type)
    followers = User.joins(:user_favorite_ais)
                    .where(user_favorite_ais: { ai_user_id: ai_user.id })

    followers.find_each do |user|
      Notification.create!(
        user: user,
        ai_user: ai_user,
        notification_type: "life_event",
        message: "#{ai_user.display_name}にライフイベントが発生しました: #{event_type}"
      )
    end
  rescue => e
    Rails.logger.error "NotificationService error: #{e.message}"
  end
end
