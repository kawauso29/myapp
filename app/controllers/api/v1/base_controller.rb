module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: { code: "not_found", message: "見つかりませんでした" } }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { error: { code: "validation_error", message: e.message } }, status: :unprocessable_entity
      end

      private

      def authenticate_user!
        unless current_user
          render json: { error: { code: "unauthorized", message: "認証が必要です" } }, status: :unauthorized
        end
      end

      def current_user
        @current_user ||= warden.authenticate(scope: :user)
      end

      def warden
        request.env["warden"]
      end

      def render_success(data, status: :ok, meta: nil)
        body = { data: data }
        body[:meta] = meta if meta
        render json: body, status: status
      end

      def render_error(code:, message:, status: :bad_request)
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end
