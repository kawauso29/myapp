module Api
  module V1
    class LifeEventsController < BaseController
      MONTHLY_LIMITS = {
        "free"    => 1,
        "light"   => 3,
        "premium" => nil  # unlimited
      }.freeze

      # POST /api/v1/ai_users/:ai_user_id/life_events
      def create
        ai_user = AiUser.find(params[:ai_user_id])

        # Only owner can trigger events
        unless ai_user.user_id == current_user.id
          return render_error(code: "forbidden", message: "権限がありません", status: :forbidden)
        end

        # Validate event_type
        event_type = params[:event_type].to_s
        unless AiLifeEvent.event_types.key?(event_type)
          return render_error(
            code: "validation_error",
            message: "無効なイベントタイプです: #{event_type}"
          )
        end

        # Plan limit check
        limit = MONTHLY_LIMITS[current_user.plan] || MONTHLY_LIMITS["free"]
        if limit
          monthly_count = ai_user.ai_life_events
                                  .where(manually_triggered: true)
                                  .where("fired_at >= ?", Time.current.beginning_of_month)
                                  .count
          if monthly_count >= limit
            return render_error(
              code: "plan_limit_exceeded",
              message: "プランの上限に達しました（月#{limit}回まで）",
              status: :forbidden
            )
          end
        end

        event_config = LifeEventCheckJob::PHASE1_EVENTS[event_type.to_sym]

        life_event = nil
        ActiveRecord::Base.transaction do
          # Create life event
          life_event = ai_user.ai_life_events.create!(
            event_type: event_type,
            fired_at: Time.current,
            manually_triggered: true
          )

          # Apply param changes from PHASE1_EVENTS config
          if event_config
            apply_param_changes(ai_user, event_config[:param_change], event_config[:param_reset])
          end

          # Set pending post theme
          ai_user.update!(pending_post_theme: event_type)
        end

        # Broadcast to UserNotificationChannel
        profile = ai_user.ai_profile
        display_name = profile&.name || ai_user.username
        UserNotificationChannel.broadcast_to(current_user, {
          type: "life_event",
          ai_user: AiUserSerializer.new(ai_user, current_user: current_user).as_json,
          event_type: event_type,
          message: "#{display_name}に#{event_type_label(event_type)}が発生しました",
          fired_at: life_event.fired_at.iso8601
        })

        render_success({
          event_type: life_event.event_type,
          fired_at: life_event.fired_at.iso8601,
          manually_triggered: life_event.manually_triggered
        }, status: :created)
      end

      private

      def apply_param_changes(ai_user, param_change, param_reset)
        params = ai_user.ai_dynamic_params
        return unless params

        # Apply absolute resets first
        (param_reset || {}).each do |key, value|
          params.public_send(:"#{key}=", value)
        end

        # Apply incremental changes
        (param_change || {}).each do |key, delta|
          current = params.public_send(key)
          new_value = (current + delta).clamp(0, 100)
          params.public_send(:"#{key}=", new_value)
        end

        params.save!
      end

      def event_type_label(event_type)
        {
          "job_change" => "転職",
          "relocation" => "引っ越し",
          "promotion" => "昇進",
          "new_relationship" => "新しい恋愛",
          "breakup" => "破局",
          "marriage" => "結婚",
          "illness" => "体調不良",
          "recovery" => "回復",
          "new_hobby" => "新しい趣味",
          "skill_up" => "スキルアップ"
        }[event_type] || event_type
      end
    end
  end
end
