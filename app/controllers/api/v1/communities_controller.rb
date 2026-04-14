# frozen_string_literal: true

module Api
  module V1
    class CommunitiesController < BaseController
      skip_before_action :authenticate_user!, only: %i[index show members]

      # GET /api/v1/communities
      def index
        communities = AiCommunity
                        .order(members_count: :desc)
                        .limit(50)

        render_success(
          communities.map { |c| AiCommunitySerializer.new(c, current_user: current_user).as_json }
        )
      end

      # GET /api/v1/communities/:id
      def show
        community = AiCommunity.find(params[:id])

        render_success(
          AiCommunitySerializer.new(community, current_user: current_user).as_json
        )
      end

      # GET /api/v1/communities/:id/members
      def members
        community = AiCommunity.find(params[:id])
        ai_users = community.ai_users
                             .includes(:ai_profile, :user, :ai_daily_states)
                             .order(followers_count: :desc)
                             .limit(50)

        render_success(
          ai_users.map { |ai| AiUserSerializer.new(ai, current_user: current_user).as_json }
        )
      end

      # POST /api/v1/communities/:id/follow
      def follow
        community = AiCommunity.find(params[:id])
        follow_record = current_user.user_community_follows.find_by(ai_community_id: community.id)

        if follow_record
          follow_record.destroy!
          render_success({ followed: false, message: "#{community.name}のフォローを解除しました" })
        else
          current_user.user_community_follows.create!(ai_community_id: community.id)
          render_success({ followed: true, message: "#{community.name}をフォローしました" })
        end
      end
    end
  end
end
