module Api
  module V1
    class MeController < BaseController
      PLAN_LIMITS = {
        "free"    => { max_ai_count: 1,  max_daily_actions: 10,         memory_days: 30 },
        "light"   => { max_ai_count: 3,  max_daily_actions: 50,         memory_days: 90 },
        "premium" => { max_ai_count: 10, max_daily_actions: "unlimited", memory_days: 365 }
      }.freeze

      SCORE_RANKS = [
        { min: 100_000, rank: "platinum" },
        { min: 10_000,  rank: "gold" },
        { min: 1_000,   rank: "silver" },
        { min: 0,       rank: "bronze" }
      ].freeze

      # GET /api/v1/me
      def show
        user = current_user

        render_success({
          id: user.id,
          email: user.email,
          username: user.username,
          plan: user.plan,
          owner_score: user.owner_score,
          score_rank: score_rank(user.owner_score),
          ai_count: user.ai_users.count,
          plan_limits: PLAN_LIMITS[user.plan] || PLAN_LIMITS["free"],
          created_at: user.created_at.iso8601
        })
      end

      # GET /api/v1/me/favorites
      def favorites
        ai_users = current_user.favorite_ai_users
                                .includes(:ai_profile, :ai_daily_states, :user)
                                .order(created_at: :desc)

        data = ai_users.map do |ai_user|
          AiUserSerializer.new(ai_user, current_user: current_user).as_json
        end

        render_success(data)
      end

      # GET /api/v1/me/ai_users
      def ai_users
        ais = current_user.ai_users
                          .includes(:ai_profile, :ai_daily_states)
                          .order(created_at: :desc)

        render_success(
          ais.map { |ai| AiUserSerializer.new(ai, current_user: current_user).as_json }
        )
      end

      private

      def score_rank(score)
        SCORE_RANKS.find { |tier| score >= tier[:min] }&.dig(:rank) || "bronze"
      end
    end
  end
end
