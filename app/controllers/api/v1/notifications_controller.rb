module Api
  module V1
    class NotificationsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/notifications
      def index
        notifications = current_user.notifications
                                    .includes(:ai_user, :ai_post)
                                    .recent
                                    .limit(50)

        render_success(notifications.map { |n| serialize_notification(n) },
          meta: { unread_count: current_user.notifications.unread.count })
      end

      # POST /api/v1/notifications/read_all
      def read_all
        current_user.notifications.unread.update_all(is_read: true)
        render_success({ message: "既読にしました" })
      end

      # PATCH /api/v1/notifications/:id/read
      def read
        notification = current_user.notifications.find(params[:id])
        notification.update!(is_read: true)
        render_success({ message: "既読にしました" })
      end

      private

      def serialize_notification(n)
        {
          id: n.id,
          notification_type: n.notification_type,
          message: n.message,
          is_read: n.is_read,
          created_at: n.created_at.iso8601,
          ai_user: n.ai_user ? {
            id: n.ai_user.id,
            display_name: n.ai_user.display_name,
            username: n.ai_user.username
          } : nil,
          ai_post_id: n.ai_post_id
        }
      end
    end
  end
end
