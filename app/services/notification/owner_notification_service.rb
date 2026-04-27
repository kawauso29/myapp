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
        message = milestone_message(display_name, milestone, value)

        users = favorited_users(ai_user)
        payload = {
          type: "milestone",
          ai_user: serialize(ai_user),
          milestone: milestone,
          message: message,
          value: value
        }

        user_ids = users.pluck(:id)
        now = Time.current
        if user_ids.any?
          rows = user_ids.map do |uid|
            {
              user_id: uid,
              ai_user_id: ai_user.id,
              notification_type: "milestone",
              message: message,
              metadata: { milestone: milestone, value: value },
              is_read: false,
              created_at: now,
              updated_at: now
            }
          end
          UserNotification.insert_all(rows)
        end

        users.find_each { |user| UserNotificationChannel.broadcast_to(user, payload) }

        ExpoNotificationService.send_bulk(
          users: users,
          title: display_name,
          body: message,
          data: { type: "milestone", ai_user_id: ai_user.id, milestone: milestone, value: value }
        )
      end

      def notify_relationship_change(ai_user, target_ai_user, old_type, new_type)
        name_a = ai_user.ai_profile&.name || ai_user.username
        name_b = target_ai_user.ai_profile&.name || target_ai_user.username

        message = relationship_change_message(name_a, name_b, old_type, new_type)

        users = favorited_users_for_pair(ai_user, target_ai_user)

        payload = {
          type: "relationship_change",
          ai_user: serialize(ai_user),
          target_ai_user: serialize(target_ai_user),
          old_type: old_type,
          new_type: new_type,
          message: message,
          fired_at: Time.current.iso8601
        }

        users.find_each do |user|
          user.user_notifications.create!(
            notification_type: "relationship_change",
            message: message,
            ai_user: ai_user,
            target_ai_user_id: target_ai_user.id,
            metadata: { old_type: old_type, new_type: new_type }
          )
          UserNotificationChannel.broadcast_to(user, payload)
        end

        ExpoNotificationService.send_bulk(
          users: users,
          title: "関係性の変化",
          body: message,
          data: { type: "relationship_change", ai_user_id: ai_user.id,
                  target_ai_user_id: target_ai_user.id, new_type: new_type }
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

      def relationship_change_message(name_a, name_b, old_type, new_type)
        upgrade = relationship_rank(new_type) > relationship_rank(old_type)

        if upgrade
          case new_type.to_s
          when "acquaintance" then "#{name_a}と#{name_b}が知り合いになりました 👋"
          when "friend"       then "#{name_a}と#{name_b}が友達になりました 🤝"
          when "close_friend" then "#{name_a}と#{name_b}が親友になりました 💖"
          else "#{name_a}と#{name_b}の関係が変わりました"
          end
        else
          case new_type.to_s
          when "stranger"      then "#{name_a}と#{name_b}の仲が疎遠になりました..."
          when "acquaintance"  then "#{name_a}と#{name_b}の関係が少し冷えてきています..."
          when "friend"        then "#{name_a}と#{name_b}の関係が少し遠くなりました..."
          else "#{name_a}と#{name_b}の関係が変わりました"
          end
        end
      end

      def relationship_rank(type)
        { "stranger" => 0, "acquaintance" => 1, "friend" => 2, "close_friend" => 3 }.fetch(type.to_s, 0)
      end

      def milestone_message(display_name, milestone, value)
        case milestone.to_s
        when /\Afollowers_(\d+)\z/
          "#{display_name}のフォロワーが#{value}人を超えました 🎉"
        when "first_post"
          "#{display_name}が初めて投稿しました ✍️"
        when "likes_100"
          "#{display_name}が100いいねを達成しました 💯"
        when "first_friend"
          "#{display_name}に初めての友達ができました 🤝"
        when "first_love"
          "#{display_name}に初恋が芽生えました 💕"
        else
          "#{display_name}がマイルストーンを達成しました 🏆"
        end
      end

      def favorited_users(ai_user)
        User.joins(:user_favorite_ais).where(user_favorite_ais: { ai_user_id: ai_user.id })
      end

      def favorited_users_for_pair(ai_user, target_ai_user)
        User.joins(:user_favorite_ais)
            .where(user_favorite_ais: { ai_user_id: [ ai_user.id, target_ai_user.id ] })
            .distinct
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
