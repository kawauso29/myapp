module Api
  module V1
    class InterventionsController < BaseController
      ALLOWED_POST_THEMES = AiUser.pending_post_themes.keys.freeze

      # POST /api/v1/ai_users/:ai_user_id/intervene
      def create
        ai_user = current_user.ai_users.find_by(id: params[:ai_user_id])

        unless ai_user
          return render_error(code: "forbidden", message: "自分のAIにのみ介入できます", status: :forbidden)
        end

        case params[:action_type]
        when "set_post_theme"
          handle_set_post_theme(ai_user)
        when "trigger_life_event"
          handle_trigger_life_event(ai_user)
        when "boost_friendship"
          handle_boost_friendship(ai_user)
        else
          render_error(code: "validation_error", message: "不明なアクションタイプです")
        end
      end

      private

      def handle_set_post_theme(ai_user)
        theme = params[:theme].to_s
        unless ALLOWED_POST_THEMES.include?(theme)
          return render_error(code: "validation_error",
                              message: "無効なテーマです。利用可能: #{ALLOWED_POST_THEMES.join(', ')}")
        end

        ai_user.update!(pending_post_theme: theme)

        render_success({
          message: "「#{theme}」テーマを設定しました。次回の投稿に反映されます。",
          pending_post_theme: theme
        })
      end

      def handle_trigger_life_event(ai_user)
        event_type = params[:event_type].to_s
        allowed = AiLifeEvent.event_types.keys
        unless allowed.include?(event_type)
          return render_error(code: "validation_error",
                              message: "無効なイベントタイプです。利用可能: #{allowed.join(', ')}")
        end

        ai_user.ai_life_events.create!(
          event_type: event_type,
          fired_at: Time.current,
          manually_triggered: true
        )
        ai_user.update!(pending_post_theme: event_type)

        Notification::OwnerNotificationService.notify_life_event(ai_user, event_type)

        render_success({
          message: "「#{event_type}」イベントを発生させました。",
          event_type: event_type
        }, status: :created)
      end

      def handle_boost_friendship(ai_user)
        target_id = params[:target_ai_user_id].to_i
        unless target_id > 0 && AiUser.exists?(id: target_id)
          return render_error(code: "not_found", message: "対象のAIユーザーが見つかりません", status: :not_found)
        end

        if target_id == ai_user.id
          return render_error(code: "validation_error", message: "自分自身には介入できません")
        end

        AiAction::RelationshipUpdater.update(ai_user.id, target_id, :followed)

        render_success({
          message: "友好的なアクションを実行しました。",
          ai_user_id: ai_user.id,
          target_ai_user_id: target_id
        })
      end
    end
  end
end
