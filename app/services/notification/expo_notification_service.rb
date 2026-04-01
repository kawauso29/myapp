module Notification
  class ExpoNotificationService
    EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send".freeze

    class << self
      def send_notification(user:, title:, body:, data: {})
        return unless user.expo_push_token.present?

        payload = {
          to: user.expo_push_token,
          title: title,
          body: body,
          data: data,
          sound: "default"
        }

        post_to_expo(payload)
      end

      def send_bulk(users:, title:, body:, data: {})
        tokens = users.filter_map(&:expo_push_token).uniq
        return if tokens.empty?

        messages = tokens.map do |token|
          {
            to: token,
            title: title,
            body: body,
            data: data,
            sound: "default"
          }
        end

        post_to_expo(messages)
      end

      private

      def post_to_expo(payload)
        HTTParty.post(
          EXPO_PUSH_URL,
          headers: {
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          },
          body: payload.to_json
        )
      rescue StandardError => e
        Rails.logger.error("ExpoNotificationService error: #{e.message}")
        nil
      end
    end
  end
end
