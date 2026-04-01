module Api
  module V1
    class PushTokensController < BaseController
      def create
        token = params[:token]
        if token.blank?
          return render_error(code: "validation_error", message: "トークンが必要です", status: :unprocessable_entity)
        end

        current_user.update!(expo_push_token: token)
        render_success({ expo_push_token: current_user.expo_push_token })
      end

      def destroy
        current_user.update!(expo_push_token: nil)
        head :no_content
      end
    end
  end
end
