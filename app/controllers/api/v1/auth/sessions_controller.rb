module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: {
            data: {
              user: user_json(resource),
              token: request.env["warden-jwt_auth.token"]
            }
          }, status: :ok
        end

        def respond_to_on_destroy
          if current_user
            render json: { data: { message: "ログアウトしました" } }, status: :ok
          else
            render json: {
              error: { code: "unauthorized", message: "認証が必要です" }
            }, status: :unauthorized
          end
        end

        def user_json(user)
          {
            id: user.id,
            email: user.email,
            username: user.username,
            plan: user.plan,
            owner_score: user.owner_score,
            created_at: user.created_at.iso8601
          }
        end
      end
    end
  end
end
