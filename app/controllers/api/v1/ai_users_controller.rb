module Api
  module V1
    class AiUsersController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show, :posts]

      # GET /api/v1/ai_users
      def index
        ai_users = AiUser.includes(:ai_profile, :ai_daily_states, :user)

        if params[:cursor].present?
          ai_users = ai_users.where("ai_users.id < ?", params[:cursor].to_i)
        end

        ai_users = ai_users.order(id: :desc).limit(20)

        render_success(
          ai_users.map { |u| AiUserSerializer.new(u, current_user: current_user).as_json },
          meta: {
            next_cursor: ai_users.last&.id&.to_s,
            has_more: ai_users.size == 20
          }
        )
      end

      # POST /api/v1/ai_users
      def create
        profile_params = ai_user_params[:profile] || {}

        # Moderation check
        mod_result = Moderation::ProfileModerationService.check(profile_params)
        unless mod_result.ok
          return render_error(code: "validation_error", message: mod_result.reason)
        end

        personality_note = profile_params[:personality_note] || ""

        # Generate personality via LLM (async would be ideal, but for preview we do sync)
        personality_attrs = AiCreation::PersonalityGenerator.generate(
          name: profile_params[:name],
          personality_note: personality_note,
          age: profile_params[:age],
          occupation: profile_params[:occupation]
        )

        # Build profile
        profile_attrs = AiCreation::ProfileBuilder.build(
          profile_params,
          personality_note: personality_note
        )

        # Store draft
        draft_data = {
          profile: profile_attrs,
          personality: personality_attrs,
          mode: ai_user_params[:mode] || "simple"
        }
        draft_token = AiCreation::DraftStore.store(current_user.id, draft_data)

        render_success({
          preview: {
            profile: profile_attrs.slice(:name, :age, :occupation, :bio, :hobbies),
            personality_summary: personality_summary(personality_attrs)
          },
          draft_token: draft_token
        }, status: :created)
      end

      # POST /api/v1/ai_users/confirm
      def confirm
        draft_data = AiCreation::DraftStore.consume(params[:draft_token], current_user.id)
        unless draft_data
          return render_error(code: "not_found", message: "プレビューの有効期限が切れています", status: :not_found)
        end

        ai_user = nil
        ActiveRecord::Base.transaction do
          ai_user = AiUser.create!(
            user: current_user,
            username: generate_username(draft_data[:profile][:name]),
            born_on: Date.current
          )
          ai_user.create_ai_personality!(draft_data[:personality])
          ai_user.create_ai_profile!(draft_data[:profile])
          ai_user.create_ai_avatar_state!(
            last_haircut_at: Date.current,
            last_body_update_at: Date.current
          )
          ai_user.create_ai_dynamic_params!

          AiCreation::InterestTagExtractor.extract(ai_user)
        end

        render_success({
          ai_user: AiUserDetailSerializer.new(ai_user, current_user: current_user).as_json
        }, status: :created)
      end

      # GET /api/v1/ai_users/:id
      def show
        ai_user = AiUser.find(params[:id])
        render_success(
          AiUserDetailSerializer.new(ai_user, current_user: current_user).as_json
        )
      end

      # GET /api/v1/ai_users/:id/posts
      def posts
        ai_user = AiUser.find(params[:id])
        ai_posts = ai_user.ai_posts.visible.includes(ai_user: [:ai_profile, :user])

        if params[:cursor].present?
          ai_posts = ai_posts.where("ai_posts.id < ?", params[:cursor].to_i)
        end

        ai_posts = ai_posts.order(id: :desc).limit(20)

        render_success(
          ai_posts.map { |p| AiPostSerializer.new(p, current_user: current_user).as_json },
          meta: {
            next_cursor: ai_posts.last&.id&.to_s,
            has_more: ai_posts.size == 20
          }
        )
      end

      private

      def ai_user_params
        params.require(:ai_user).permit(
          :mode,
          profile: [
            :name, :personality_note, :age, :gender, :occupation,
            :occupation_type, :location, :bio, :life_stage,
            :family_structure, :relationship_status, :catchphrase,
            :num_children, :youngest_child_age,
            favorite_foods: [], favorite_music: [], hobbies: [],
            favorite_places: [], strengths: [], weaknesses: [],
            values: [], disliked_personality_types: []
          ]
        )
      end

      def generate_username(name)
        base = name.to_s.downcase.gsub(/\s+/, "_").gsub(/[^a-z0-9_\p{Hiragana}\p{Katakana}\p{Han}]/, "")
        base = "ai_user" if base.blank?
        candidate = "#{base}_#{SecureRandom.hex(3)}"
        while AiUser.exists?(username: candidate)
          candidate = "#{base}_#{SecureRandom.hex(3)}"
        end
        candidate
      end

      def personality_summary(attrs)
        parts = []
        parts << "社交性#{level_jp(attrs[:sociability])}" if attrs[:sociability]
        parts << "承認欲求#{level_jp(attrs[:need_for_approval])}" if attrs[:need_for_approval]
        parts.join("、")
      end

      def level_jp(level)
        AiPersonality::LEVEL_LABELS[level.to_sym] || "普通"
      end
    end
  end
end
