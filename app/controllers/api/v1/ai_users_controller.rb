module Api
  module V1
    class AiUsersController < BaseController
      # Maximum possible difference between two personality level values (very_low=1 to very_high=5)
      MAX_PERSONALITY_LEVEL_DIFF = 4.0

      skip_before_action :authenticate_user!, only: [ :index, :show, :posts, :life_story, :relationship_map, :compatibility ]

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

        # LLM呼び出しはトランザクション外で事前生成（長時間ロック防止）
        close_people_attrs = AiCreation::ClosePeopleBuilder.build(draft_data[:profile])

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

          close_people_attrs.each do |attrs|
            ai_user.ai_close_people.create!(attrs)
          end

          AiCreation::InterestTagExtractor.extract(ai_user)
        end

        render_success({
          ai_user: AiUserDetailSerializer.new(ai_user, current_user: current_user).as_json
        }, status: :created)
      end

      # GET /api/v1/ai_users/:id
      def show
        ai_user = AiUser.includes(:ai_profile, :ai_personality, :ai_dynamic_params,
                                   :ai_daily_states, :user).find(params[:id])
        render_success(
          AiUserDetailSerializer.new(ai_user, current_user: current_user).as_json
        )
      end

      # GET /api/v1/ai_users/:id/posts
      def posts
        ai_user = AiUser.find(params[:id])
        ai_posts = ai_user.ai_posts.visible.includes(ai_user: [ :ai_profile, :user ])

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

      # GET /api/v1/ai_users/:id/life_story
      def life_story
        ai_user = AiUser.find(params[:id])

        cache_key = "ai_user/#{ai_user.id}/life_story/#{ai_user.updated_at.to_i}"
        story = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          generate_life_story(ai_user)
        end

        render_success(story)
      end

      # GET /api/v1/ai_users/:id/relationship_map
      def relationship_map
        ai_user = AiUser.find(params[:id])

        relationships = ai_user.ai_relationships
                               .where.not(relationship_type: :stranger)
                               .includes(target_ai_user: [ :ai_profile, :ai_daily_states ])
                               .order(interaction_score: :desc)
                               .limit(50)

        nodes = [ build_node(ai_user) ]
        edges = []
        seen_ids = Set.new([ ai_user.id ])

        relationships.each do |rel|
          target = rel.target_ai_user
          unless seen_ids.include?(target.id)
            nodes << build_node(target)
            seen_ids.add(target.id)
          end

          edges << {
            source: ai_user.id,
            target: target.id,
            relationship_type: rel.relationship_type,
            interaction_score: rel.interaction_score
          }
        end

        render_success({ nodes: nodes, edges: edges })
      end

      # GET /api/v1/ai_users/:id/compatibility?target_id=:target_id
      def compatibility
        ai_user = AiUser.includes(:ai_personality, :ai_profile, :interest_tags).find(params[:id])
        target  = AiUser.includes(:ai_personality, :ai_profile, :interest_tags).find(params[:target_id])

        render_success(calculate_compatibility(ai_user, target))
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "AIユーザーが見つかりません")
      end

      private

      def build_node(ai_user)
        {
          id: ai_user.id,
          display_name: ai_user.ai_profile&.name || ai_user.username,
          username: ai_user.username,
          followers_count: ai_user.followers_count,
          today_mood: ai_user.today_state&.mood
        }
      end

      def calculate_compatibility(a, b)
        pa = a.ai_personality
        pb = b.ai_personality

        personality_score = if pa && pb
          lv = AiPersonality::LEVEL_ENUM
          attrs = %i[empathy curiosity optimism humor]
          diffs = attrs.map { |attr| (lv[pa.public_send(attr).to_sym] - lv[pb.public_send(attr).to_sym]).abs }
          max_diff = attrs.size * MAX_PERSONALITY_LEVEL_DIFF
          100 - ((diffs.sum / max_diff) * 100).round
        else
          50
        end

        tag_a = a.interest_tags.pluck(:name).to_set
        tag_b = b.interest_tags.pluck(:name).to_set
        interest_score = if (tag_a | tag_b).empty?
          50
        else
          ((tag_a & tag_b).size / (tag_a | tag_b).size.to_f * 100).round
        end

        total = (personality_score * 0.6 + interest_score * 0.4).round

        label =
          case total
          when 80..100 then "最高の相性 💖"
          when 60..79  then "相性が良い 😊"
          when 40..59  then "普通の相性 🤝"
          else              "個性が強め 🌀"
          end

        {
          ai_user_id: a.id,
          target_ai_user_id: b.id,
          total_score: total,
          personality_score: personality_score,
          interest_score: interest_score,
          label: label,
          shared_interests: (tag_a & tag_b).to_a
        }
      end

      def generate_life_story(ai_user)
        profile = ai_user.ai_profile
        display_name = profile&.name || ai_user.username

        life_events = ai_user.ai_life_events
                             .order(fired_at: :asc)
                             .limit(20)
                             .map { |e| "#{e.fired_at.strftime('%Y年%m月')}: #{e.event_type}" }

        memories = ai_user.ai_long_term_memories
                          .order(occurred_on: :asc)
                          .limit(20)
                          .map { |m| "#{m.occurred_on.strftime('%Y年%m月')}: #{m.content}" }

        if life_events.empty? && memories.empty?
          return {
            ai_user_id: ai_user.id,
            display_name: display_name,
            story: "#{display_name}はまだ歩み始めたばかりです。これからどんな物語が生まれるか楽しみです。",
            generated_at: Time.current.iso8601
          }
        end

        prompt = build_life_story_prompt(display_name, profile, life_events, memories)
        story_text = LlmClient.call(prompt, purpose: :post, max_tokens: 500)

        {
          ai_user_id: ai_user.id,
          display_name: display_name,
          story: story_text.strip,
          life_event_count: life_events.size,
          memory_count: memories.size,
          generated_at: Time.current.iso8601
        }
      end

      def build_life_story_prompt(display_name, profile, life_events, memories)
        profile_info = if profile
          "年齢: #{profile.age}歳, 職業: #{profile.occupation}, 性格: #{profile.bio&.truncate(100)}"
        else
          ""
        end

        events_text = life_events.any? ? "【ライフイベント】\n#{life_events.join("\n")}" : ""
        memories_text = memories.any? ? "【記憶・出来事】\n#{memories.join("\n")}" : ""

        <<~PROMPT
          以下はAIキャラクター「#{display_name}」のプロフィールと歩みです。
          #{profile_info}

          #{events_text}

          #{memories_text}

          上記の情報をもとに、「#{display_name}」のこれまでの歩みを、200〜300文字の日本語で温かく・ドラマチックに「あらすじ」としてまとめてください。
          三人称で書き、読んでいる人が感情移入できるような文体にしてください。
        PROMPT
      end

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
