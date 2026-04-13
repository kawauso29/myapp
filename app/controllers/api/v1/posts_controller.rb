module Api
  module V1
    class PostsController < BaseController
      TIMELINE_PAGE_SIZE = 20
      TIMELINE_CANDIDATE_SIZE = 60
      HOT_POST_WINDOW = 6.hours
      MISSED_POST_MIN_AGE = 6.hours

      skip_before_action :authenticate_user!, only: [ :index, :show ]

      # GET /api/v1/posts/following
      def following
        return render_error(code: "unauthorized", message: "ログインが必要です", status: :unauthorized) unless current_user

        followed_ai_ids = current_user.favorite_ai_users.pluck(:id)

        if followed_ai_ids.empty?
          return render_success([], meta: { next_cursor: nil, has_more: false })
        end

        scope = AiPost.visible
                      .where(ai_user_id: followed_ai_ids)
                      .includes(:interest_tags, ai_user: [ :ai_profile, :ai_daily_states, :user ])

        if params[:before].present?
          cursor = Time.parse(params[:before])
          scope = scope.where("ai_posts.created_at < ?", cursor)
        end

        posts = build_ranked_timeline(scope)
        has_more = scope.order(created_at: :desc).offset(TIMELINE_PAGE_SIZE).exists?

        render_success(
          posts.map { |p| AiPostSerializer.new(p, current_user: current_user).as_json },
          meta: {
            next_cursor: posts.last&.created_at&.iso8601,
            has_more: has_more,
            timeline_sections: timeline_sections(scope)
          }
        )
      end

      # GET /api/v1/posts
      def index
        scope = AiPost.visible.includes(:interest_tags, ai_user: [ :ai_profile, :ai_daily_states, :user ])

        if params[:before].present?
          cursor = Time.parse(params[:before])
          scope = scope.where("ai_posts.created_at < ?", cursor)
        end

        posts = build_ranked_timeline(scope)
        has_more = scope.order(created_at: :desc).offset(TIMELINE_PAGE_SIZE).exists?

        render_success(
          posts.map { |p| AiPostSerializer.new(p, current_user: current_user).as_json },
          meta: {
            next_cursor: posts.last&.created_at&.iso8601,
            has_more: has_more,
            timeline_sections: timeline_sections(scope)
          }
        )
      end

      # GET /api/v1/posts/:id
      def show
        post = AiPost.visible.find(params[:id])
        replies = post.replies.visible.includes(ai_user: [ :ai_profile, :user ]).order(created_at: :asc)

        data = AiPostSerializer.new(post, current_user: current_user).as_json
        data[:replies] = replies.map { |r| AiPostSerializer.new(r, current_user: current_user).as_json }

        render_success(data)
      end

      private

      def build_ranked_timeline(scope)
        candidates = scope.order(created_at: :desc).limit(TIMELINE_CANDIDATE_SIZE).to_a
        return candidates.first(TIMELINE_PAGE_SIZE) unless current_user

        liked_ai_ids = liked_ai_user_ids
        liked_tag_ids = liked_interest_tag_ids

        candidates
          .sort_by { |post| [ -timeline_score(post, liked_ai_ids, liked_tag_ids), -post.created_at.to_i ] }
          .first(TIMELINE_PAGE_SIZE)
      end

      def timeline_sections(scope)
        return {} unless current_user

        {
          hot_posts: serialize_posts(select_hot_posts(scope)),
          missed_posts: serialize_posts(select_missed_posts(scope))
        }
      end

      def select_hot_posts(scope)
        scope.where("ai_posts.created_at >= ?", HOT_POST_WINDOW.ago)
             .where("ai_posts.likes_count > 0")
             .order(created_at: :desc)
             .limit(TIMELINE_CANDIDATE_SIZE)
             .to_a
             .sort_by { |post| -hot_score(post) }
             .first(5)
      end

      def select_missed_posts(scope)
        followed_ai_ids = current_user.favorite_ai_users.pluck(:id)
        return [] if followed_ai_ids.empty?

        liked_post_ids = UserAiLike.where(user_id: current_user.id).select(:ai_post_id)

        scope.where(ai_user_id: followed_ai_ids)
             .where("ai_posts.created_at <= ?", MISSED_POST_MIN_AGE.ago)
             .where.not(id: liked_post_ids)
             .order(created_at: :desc)
             .limit(5)
      end

      def serialize_posts(posts)
        posts.map { |post| AiPostSerializer.new(post, current_user: current_user).as_json }
      end

      def liked_ai_user_ids
        UserAiLike.where(user_id: current_user.id)
                  .joins(:ai_post)
                  .group("ai_posts.ai_user_id")
                  .order(Arel.sql("COUNT(*) DESC"))
                  .limit(5)
                  .count
                  .keys
      end

      def liked_interest_tag_ids
        PostInterestTag.joins(ai_post: :user_ai_likes)
                       .where(user_ai_likes: { user_id: current_user.id })
                       .group(:interest_tag_id)
                       .order(Arel.sql("COUNT(*) DESC"))
                       .limit(8)
                       .count
                       .keys
      end

      def timeline_score(post, liked_ai_ids, liked_tag_ids)
        score = 0
        score += 35 if liked_ai_ids.include?(post.ai_user_id)
        score += (post.interest_tags.map(&:id) & liked_tag_ids).size * 12
        score += [ post.likes_count, 20 ].min
        score += [ post.replies_count * 2, 10 ].min

        hours_ago = (Time.current - post.created_at) / 3600.0
        score + [ (12 - hours_ago).to_i, 0 ].max
      end

      def hot_score(post)
        hours_since_post = [ (Time.current - post.created_at) / 3600.0, 1.0 ].max
        post.likes_count / hours_since_post
      end
    end
  end
end
