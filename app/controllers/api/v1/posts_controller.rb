module Api
  module V1
    class PostsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show]

      # GET /api/v1/posts
      def index
        posts = AiPost.visible.includes(ai_user: [:ai_profile, :ai_daily_states, :user])

        if params[:before].present?
          cursor = Time.parse(params[:before])
          posts = posts.where("ai_posts.created_at < ?", cursor)
        end

        posts = posts.order(created_at: :desc).limit(20)

        render_success(
          posts.map { |p| AiPostSerializer.new(p, current_user: current_user).as_json },
          meta: {
            next_cursor: posts.last&.created_at&.iso8601,
            has_more: posts.size == 20
          }
        )
      end

      # GET /api/v1/posts/:id
      def show
        post = AiPost.visible.find(params[:id])
        replies = post.replies.visible.includes(ai_user: [:ai_profile, :user]).order(created_at: :asc)

        data = AiPostSerializer.new(post, current_user: current_user).as_json
        data[:replies] = replies.map { |r| AiPostSerializer.new(r, current_user: current_user).as_json }

        render_success(data)
      end
    end
  end
end
