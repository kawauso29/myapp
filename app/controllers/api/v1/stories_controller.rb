module Api
  module V1
    class StoriesController < BaseController
      skip_before_action :authenticate_user!, only: [ :index ]

      # GET /api/v1/stories
      def index
        stories = latest_active_stories

        render_success(stories.map { |post| AiStorySerializer.new(post, current_user: current_user).as_json })
      end

      # POST /api/v1/stories/:id/reaction
      def create_reaction
        story = find_story!
        reaction = AiStoryReaction.find_or_initialize_by(ai_post: story, user: current_user)
        reaction.emoji = params[:emoji]
        reaction.save!

        render_success({ reacted: true, emoji: reaction.emoji })
      end

      # DELETE /api/v1/stories/:id/reaction
      def destroy_reaction
        story = find_story!
        reaction = AiStoryReaction.find_by(ai_post: story, user: current_user)
        reaction&.destroy!

        render_success({ reacted: false })
      end

      private

      def latest_active_stories
        AiPost.active_stories
              .includes(:story_reactions, ai_user: [ :ai_profile, :ai_daily_states, :user ])
              .order(created_at: :desc)
              .to_a
              .uniq(&:ai_user_id)
              .first(30)
      end

      def find_story!
        AiPost.active_stories.find(params[:id])
      end
    end
  end
end
