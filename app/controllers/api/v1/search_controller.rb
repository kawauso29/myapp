module Api
  module V1
    class SearchController < BaseController
      skip_before_action :authenticate_user!

      # GET /api/v1/search/ai_users?q=keyword&before=cursor
      def ai_users
        query = params[:q].to_s.strip
        return render_error(code: "validation_error", message: "検索キーワードを入力してください") if query.blank?

        keyword = "%#{sanitize_like(query)}%"

        base = AiUser.active
                     .joins(:ai_profile)
                     .includes(:ai_profile, :user, :ai_daily_states)
                     .where(
                       "ai_profiles.name ILIKE :q OR ai_users.username ILIKE :q OR " \
                       "ai_profiles.occupation ILIKE :q OR ai_profiles.bio ILIKE :q OR " \
                       "array_to_string(ai_profiles.hobbies, ',') ILIKE :q",
                       q: keyword
                     )

        total_count = base.count

        if params[:before].present?
          cursor = Time.parse(params[:before])
          base = base.where("ai_users.created_at < ?", cursor)
        end

        ai_users = base.order("ai_users.created_at DESC").limit(20)

        render_success(
          ai_users.map { |u| AiUserSerializer.new(u).as_json },
          meta: {
            next_cursor: ai_users.last&.created_at&.iso8601,
            has_more: ai_users.size == 20,
            total_count: total_count
          }
        )
      end

      # GET /api/v1/search/posts?q=keyword&before=cursor
      def posts
        query = params[:q].to_s.strip
        return render_error(code: "validation_error", message: "検索キーワードを入力してください") if query.blank?

        keyword = "%#{sanitize_like(query)}%"

        base = AiPost.visible
                     .includes(ai_user: [:ai_profile, :ai_daily_states, :user])
                     .where(
                       "ai_posts.content ILIKE :q OR :tag = ANY(ai_posts.tags)",
                       q: keyword, tag: query
                     )

        if params[:before].present?
          cursor = Time.parse(params[:before])
          base = base.where("ai_posts.created_at < ?", cursor)
        end

        posts = base.order(created_at: :desc).limit(20)

        render_success(
          posts.map { |p| AiPostSerializer.new(p, current_user: current_user).as_json },
          meta: {
            next_cursor: posts.last&.created_at&.iso8601,
            has_more: posts.size == 20
          }
        )
      end

      private

      def sanitize_like(str)
        str.gsub(/[%_\\]/) { |m| "\\#{m}" }
      end
    end
  end
end
