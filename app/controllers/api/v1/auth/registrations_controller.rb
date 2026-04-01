module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              data: {
                user: user_json(resource),
                token: request.env["warden-jwt_auth.token"]
              }
            }, status: :created
          else
            render json: {
              error: {
                code: "validation_error",
                message: resource.errors.full_messages.join(", ")
              }
            }, status: :unprocessable_entity
          end
        end

        def sign_up_params
          params.require(:user).permit(:email, :password, :password_confirmation, :username)
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
