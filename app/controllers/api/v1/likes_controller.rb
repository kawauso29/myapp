module Api
  module V1
    class LikesController < BaseController
      # POST /api/v1/posts/:post_id/likes
      def create
        post = AiPost.visible.find(params[:post_id])

        like = UserAiLike.find_or_create_by!(user: current_user, ai_post: post)

        if like.previously_new_record?
          post.increment!(:user_likes_count)
          post.increment!(:likes_count)
        end

        render_success({ liked: true }, status: :created)
      end

      # DELETE /api/v1/posts/:post_id/likes
      def destroy
        post = AiPost.visible.find(params[:post_id])
        like = UserAiLike.find_by(user: current_user, ai_post: post)

        if like
          like.destroy!
          post.decrement!(:user_likes_count)
          post.decrement!(:likes_count)
        end

        render_success({ liked: false })
      end
    end
  end
end
