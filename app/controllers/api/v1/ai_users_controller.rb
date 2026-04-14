module Api
  module V1
    class AiUsersController < BaseController
      # Maximum possible difference between two personality level values (very_low=1 to very_high=5)
      MAX_PERSONALITY_LEVEL_DIFF = 4.0
      MULTIVERSE_EVENT_LABELS = {
        "job_change" => "転職",
        "relocation" => "引越し",
        "promotion" => "昇進",
        "new_relationship" => "新しい恋",
        "breakup" => "失恋",
        "marriage" => "結婚",
        "illness" => "体調不良",
        "recovery" => "回復",
        "new_hobby" => "新しい趣味",
        "skill_up" => "スキルアップ"
      }.freeze

      skip_before_action :authenticate_user!, only: [ :index, :show, :posts, :life_story, :relationship_map, :compatibility, :multiverse ]

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
        unless PlanEnforcer.can_create_ai?(current_user)
          return render_error(code: "plan_limit_reached", message: "AI作成上限に達しています", status: :forbidden)
        end

        profile_params = ai_user_params[:profile] || {}
        premium_requested = premium_mode_requested?

        if premium_requested && !current_user.premium?
          return render_error(code: "premium_required", message: "プレミアムプラン限定の機能です", status: :forbidden)
        end

        premium_template = premium_template_param(premium_requested)
        if premium_requested && premium_template.blank?
          return render_error(code: "invalid_template", message: "プレミアムテンプレートを選択してください")
        end

        # Moderation check
        mod_result = Moderation::ProfileModerationService.check(profile_params)
        unless mod_result.ok
          return render_error(code: "validation_error", message: mod_result.reason)
        end

        personality_note = decorated_personality_note(profile_params[:personality_note], premium_template)

        # Generate personality via LLM (async would be ideal, but for preview we do sync)
        personality_attrs = AiCreation::PersonalityGenerator.generate(
          profile_params.merge(personality_note: personality_note)
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
          mode: ai_user_params[:mode] || "simple",
          is_premium_ai: premium_requested,
          premium_personality_template: premium_template
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
            born_on: Date.current,
            is_premium_ai: draft_data[:is_premium_ai] || false,
            premium_personality_template: draft_data[:premium_personality_template]
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

        cache_key = "ai_user/#{ai_user.id}/life_story/#{life_story_cache_version(ai_user)}"
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

      # GET /api/v1/ai_users/:id/emotion_history
      # 感情ダッシュボード: 直近 30 日分の AiDailyState から感情推移を返す
      def emotion_history
        ai_user = AiUser.find(params[:id])
        days = [ (params[:days] || 30).to_i, 90 ].min
        since = days.days.ago.to_date

        states = ai_user.ai_daily_states
                        .where("date >= ?", since)
                        .order(date: :asc)
                        .select(:date, :mood, :stress_level, :post_motivation, :social_battery)

        render_success(states.map { |s| serialize_emotion_state(s) })
      end

      # GET /api/v1/ai_users/:id/multiverse?event=job_change
      def multiverse
        ai_user = AiUser.find(params[:id])
        requested_event_key = params[:event].to_s.presence || "job_change"
        event_key = MULTIVERSE_EVENT_LABELS.key?(requested_event_key) ? requested_event_key : "job_change"
        event_label = MULTIVERSE_EVENT_LABELS[event_key]

        base_timeline = build_multiverse_original_timeline(ai_user)
        multiverse_timeline = build_multiverse_if_timeline(ai_user, base_timeline, event_label)

        render_success({
          ai_user_id: ai_user.id,
          display_name: ai_user.ai_profile&.name || ai_user.username,
          scenario: {
            event_key: event_key,
            event_label: event_label
          },
          timelines: {
            original: base_timeline,
            multiverse: multiverse_timeline
          },
          generated_at: Time.current.iso8601
        })
      end

      private

      def build_multiverse_original_timeline(ai_user)
        profile_name = ai_user.ai_profile&.name || ai_user.username

        post_entries = ai_user.ai_posts.visible
                              .order(created_at: :desc)
                              .limit(8)
                              .map do |post|
          {
            occurred_at: post.created_at.iso8601,
            source: "post",
            text: post.content
          }
        end

        event_entries = ai_user.ai_life_events
                               .order(fired_at: :desc)
                               .limit(4)
                               .map do |event|
          {
            occurred_at: event.fired_at.iso8601,
            source: "life_event",
            text: "#{event.fired_at.strftime('%Y/%m/%d')} #{event.event_type}"
          }
        end

        timeline = (post_entries + event_entries)
                   .sort_by { |entry| entry[:occurred_at] }
                   .reverse
                   .first(10)

        return timeline if timeline.present?

        [
          {
            occurred_at: Time.current.iso8601,
            source: "seed",
            text: "#{profile_name}の物語はこれから始まります。"
          }
        ]
      end

      def build_multiverse_if_timeline(ai_user, base_timeline, event_label)
        profile_name = ai_user.ai_profile&.name || ai_user.username
        intro_entry = {
          occurred_at: Time.current.iso8601,
          source: "if_event",
          text: "もし#{profile_name}が「#{event_label}」を選んでいたら…"
        }

        remixed_entries = base_timeline.first(9).map.with_index do |entry, index|
          {
            occurred_at: entry[:occurred_at],
            source: entry[:source],
            text: index.zero? ? "【if世界線】#{entry[:text]}" : "if世界では: #{entry[:text]}"
          }
        end

        [ intro_entry, *remixed_entries ]
      end

      def serialize_emotion_state(state)
        # mood enum: positive=0, neutral=1, negative=2, very_negative=3
        # Convert to 0-100 scale (positive=100, very_negative=0)
        mood_score = case state.mood
        when "positive"      then 100
        when "neutral"       then 65
        when "negative"      then 35
        when "very_negative" then 0
        else 50
        end

        {
          date: state.date.iso8601,
          mood_score: mood_score,
          stress: state.stress_level,
          motivation: state.post_motivation,
          social_energy: state.social_battery
        }
      end

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
                             .map do |event|
          {
            sort_at: event.fired_at,
            line: "#{event.fired_at.strftime('%Y年%m月')}: #{event.event_type}"
          }
        end

        memories = ai_user.ai_long_term_memories
                          .order(occurred_on: :asc)
                          .limit(20)
                          .map do |memory|
          {
            sort_at: memory.occurred_on.in_time_zone,
            line: "#{memory.occurred_on.strftime('%Y年%m月')}: #{memory.content}"
          }
        end

        if life_events.empty? && memories.empty?
          return {
            ai_user_id: ai_user.id,
            display_name: display_name,
            story: "#{display_name}はまだ歩み始めたばかりです。これからどんな物語が生まれるか楽しみです。",
            generated_at: Time.current.iso8601
          }
        end

        timeline_lines = (life_events + memories)
                          .sort_by { |entry| entry[:sort_at] }
                          .map { |entry| entry[:line] }

        prompt = build_life_story_prompt(display_name, profile, timeline_lines)
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

      def build_life_story_prompt(display_name, profile, timeline_lines)
        profile_info = if profile
          "年齢: #{profile.age}歳, 職業: #{profile.occupation}, 性格: #{profile.bio&.truncate(100)}"
        else
          ""
        end

        timeline_text = "【時系列の出来事】\n#{timeline_lines.join("\n")}"

        <<~PROMPT
          以下はAIキャラクター「#{display_name}」のプロフィールと歩みです。
          #{profile_info}

          #{timeline_text}

          上記の情報をもとに、「#{display_name}」のこれまでの歩みを、200〜300文字の日本語で温かく・ドラマチックに「あらすじ」としてまとめてください。
          三人称で書き、読んでいる人が感情移入できるような文体にしてください。
        PROMPT
      end

      def life_story_cache_version(ai_user)
        [
          ai_user.updated_at&.to_i,
          ai_user.ai_life_events.maximum(:updated_at)&.to_i,
          ai_user.ai_long_term_memories.maximum(:updated_at)&.to_i
        ].compact.max || 0
      end

      def ai_user_params
        params.require(:ai_user).permit(
          :mode,
          :premium_personality_template,
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

      def premium_mode_requested?
        ai_user_params[:mode].to_s == "premium"
      end

      def premium_template_param(premium_requested)
        return nil unless premium_requested

        template = ai_user_params[:premium_personality_template].to_s
        return template if AiUser.premium_personality_templates.key?(template)

        nil
      end

      def decorated_personality_note(note, premium_template)
        base_note = note.to_s
        return base_note if premium_template.blank?

        template_text = case premium_template
        when "celebrity_style"
          "有名人のような存在感と華やかさを持つキャラクター。"
        when "anime_style"
          "アニメキャラクターのように表現豊かで印象的なキャラクター。"
        else
          ""
        end

        [ template_text, base_note ].reject(&:blank?).join("\n")
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
