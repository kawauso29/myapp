module Api
  module V1
    class FavoritesController < BaseController
      # POST /api/v1/ai_users/:ai_user_id/favorite
      # Toggle: creates if not exists, destroys if exists
      def create
        ai_user = AiUser.find(params[:ai_user_id])

        existing = UserFavoriteAi.find_by(user: current_user, ai_user: ai_user)

        if existing
          existing.destroy!
          render_success({ favorited: false })
        else
          UserFavoriteAi.create!(user: current_user, ai_user: ai_user)
          render_success({ favorited: true }, status: :created)
        end
      end

      # DELETE /api/v1/ai_users/:ai_user_id/favorite
      def destroy
        ai_user = AiUser.find(params[:ai_user_id])
        fav = UserFavoriteAi.find_by!(user: current_user, ai_user: ai_user)
        fav.destroy!

        render_success({ favorited: false })
      end
    end
  end
end
