module Notification
  class OwnerNotificationService
    class << self
      def notify_life_event(ai_user, event_type)
        display_name = ai_user.ai_profile&.name || ai_user.username
        message = "#{display_name}に「#{event_type}」が発生しました"

        users = favorited_users(ai_user)

        broadcast_to_users(users, {
          type: "life_event",
          ai_user: serialize(ai_user),
          event_type: event_type,
          message: message,
          fired_at: Time.current.iso8601
        })

        ExpoNotificationService.send_bulk(
          users: users,
          title: display_name,
          body: message,
          data: { type: "life_event", ai_user_id: ai_user.id, event_type: event_type }
        )
      end

      def notify_milestone(ai_user, milestone, value)
        display_name = ai_user.ai_profile&.name || ai_user.username
        message = "#{display_name}のフォロワーが#{value}人を超えました"

        users = favorited_users(ai_user)

        broadcast_to_users(users, {
          type: "milestone",
          ai_user: serialize(ai_user),
          milestone: milestone,
          message: message,
          value: value
        })

        ExpoNotificationService.send_bulk(
          users: users,
          title: display_name,
          body: message,
          data: { type: "milestone", ai_user_id: ai_user.id, milestone: milestone, value: value }
        )
      end

      def notify_post(ai_user, post)
        display_name = ai_user.ai_profile&.name || ai_user.username
        body_text = post.content.truncate(80)

        users = favorited_users(ai_user)

        broadcast_to_users(users, {
          type: "new_post",
          ai_user: serialize(ai_user),
          post: AiPostSerializer.new(post).as_json
        })

        ExpoNotificationService.send_bulk(
          users: users,
          title: "#{display_name}が投稿しました",
          body: body_text,
          data: { type: "new_post", ai_user_id: ai_user.id, post_id: post.id }
        )
      end

      private

      def favorited_users(ai_user)
        User.joins(:user_favorite_ais).where(user_favorite_ais: { ai_user_id: ai_user.id })
      end

      def broadcast_to_users(users, payload)
        users.find_each do |user|
          UserNotificationChannel.broadcast_to(user, payload)
        end
      end

      def serialize(ai_user)
        AiUserSerializer.new(ai_user).as_json
      end
    end
  end
end
