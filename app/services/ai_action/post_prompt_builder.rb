module AiAction
  class PostPromptBuilder
    def self.build(ai_user, daily_state, motivation)
      new(ai_user, daily_state, motivation).build
    end

    def initialize(ai_user, daily_state, motivation)
      @ai = ai_user
      @profile = ai_user.ai_profile
      @personality = ai_user.ai_personality
      @state = daily_state
      @motivation = motivation
      @current_hour = Time.current.in_time_zone("Tokyo").hour
      @schedule = ai_user.ai_daily_schedules.find_by(scheduled_date: Date.current)
    end

    def build
      <<~PROMPT
        あなたは以下の人物です。SNSに投稿してください。

        ## プロフィール
        名前: #{@profile.name}
        年齢: #{@profile.age}歳
        職業: #{@profile.occupation}
        居住地: #{@profile.location}
        自己紹介: #{@profile.bio}

        ## 好み・特性
        #{preferences_section}

        ## 性格
        #{personality_section}

        ## 今日の状態
        #{today_state_section}

        ## 今日の外部状況
        #{external_context_section}

        ## 今日のスケジュールと現在の状況
        #{schedule_section}

        #{memory_section}

        ## 今回の投稿動機
        #{motivation_text}

        ## 絶対に守ること
        - 日本語で書く
        - #{length_guide}
        - 本物の人間のSNS投稿として自然に書く
        - AIであること、AIが書いたことを示唆する表現は絶対に使わない
        - 「投稿します」などのメタ発言はしない
        - 敬語・タメ口は年齢と性格に合わせる
        - 今日の出来事・予定・気分と整合する内容にする

        ## 出力形式（JSON、他の文字は一切出力しない）
        {
          "content": "投稿本文（140文字以内）",
          "tags": ["タグ1", "タグ2", "タグ3"],
          "mood_expressed": "positive | neutral | negative",
          "emoji_used": true
        }
      PROMPT
    end

    private

    def preferences_section
      parts = []
      parts << "好きな食べ物: #{@profile.favorite_foods.first(3).join('、')}" if @profile.favorite_foods.any?
      parts << "趣味: #{@profile.hobbies.first(3).join('、')}" if @profile.hobbies.any?
      parts << "大切にしていること: #{@profile.values.first(3).join('、')}" if @profile.values.any?
      parts << "口癖: #{@profile.catchphrase}" if @profile.catchphrase.present?
      parts.join("\n")
    end

    def personality_section
      @personality.to_prompt_hash.map { |k, v| "#{k}: #{v}" }.join("\n")
    end

    def today_state_section
      parts = []
      parts << "体調: #{@state.physical}"
      parts << "気分: #{@state.mood}"
      parts << "朝の目覚め: #{@state.morning_mood}"
      parts << "忙しさ: #{@state.busyness}"
      parts << "エネルギー: #{@state.energy}"
      parts << "集中力: #{@state.concentration}"
      parts << "食欲: #{@state.appetite}"
      parts << "ストレスレベル: #{@state.stress_level}/100"
      parts << "社交エネルギー: #{@state.social_battery}/100"
      parts << "外出予定: #{@state.going_out? ? 'あり' : 'なし'}"
      parts << "飲酒中（レベル#{@state.drinking_level}/3）" if @state.is_drinking
      parts << "今日の気まぐれ: #{@state.daily_whim}"
      parts.join("\n")
    end

    def external_context_section
      parts = []
      parts << "現在時刻: #{@current_hour}時"
      parts << "曜日: #{%w[日 月 火 水 木 金 土][Date.current.wday]}曜日"
      parts << "天気: #{@state.weather_condition || 'normal'}"
      parts << "イベント: #{@state.today_events.join('、')}" if @state.today_events.any?
      season = case Date.current.month
      when 3..5 then "春"
      when 6..8 then "夏"
      when 9..11 then "秋"
      else "冬"
      end
      parts << "季節: #{season}"
      parts.join("\n")
    end

    def schedule_section
      return "（本日のスケジュールなし）" unless @schedule

      parts = []

      # 今やっていること
      current = @schedule.current_activity(@current_hour)
      parts << "今していること: #{current['activity']}（#{current['location']}）" if current

      # 直近の予定
      upcoming = @schedule.upcoming_activities(@current_hour, limit: 3)
      if upcoming.any?
        upcoming_text = upcoming.map { |u| "#{u['hour']}時: #{u['activity']}" }.join("、")
        parts << "これからの予定: #{upcoming_text}"
      end

      # 今日終わったこと
      past = @schedule.past_activities(@current_hour)
      if past.any?
        done_text = past.last(3).map { |p| p["activity"] }.join("、")
        parts << "今日やったこと: #{done_text}"
      end

      # 週の文脈
      parts << "今週の状況: #{@schedule.week_context}" if @schedule.week_context.present?

      # hourly_states から直近の状態変化
      recent_hourly = @state.hourly_states.last(2)
      if recent_hourly.any?
        mood_delta = recent_hourly.sum { |s| s["mood_delta"].to_i }
        parts << "直近の気分変化: #{mood_delta > 0 ? '+' : ''}#{mood_delta}" if mood_delta != 0
      end

      parts.any? ? parts.join("\n") : "（特定のスケジュールなし）"
    end

    def memory_section
      sections = []

      long_term = @ai.ai_long_term_memories.order(importance: :desc, occurred_on: :desc).limit(5)
      if long_term.any?
        sections << "## あなたの記憶（重要な出来事）\n" +
                    long_term.map { |m| "- #{m.occurred_on}: #{m.content}" }.join("\n")
      end

      short_term = @ai.ai_short_term_memories.active.order(created_at: :desc).limit(3)
      if short_term.any?
        sections << "## 最近の出来事\n" + short_term.map(&:content).join("\n")
      end

      sections.join("\n\n")
    end

    def length_guide
      base = 70

      if @personality&.self_expression_high? || @personality&.self_expression_very_high?
        base += 40
      elsif @personality&.self_expression_low? || @personality&.self_expression_very_low?
        base -= 30
      end

      if @personality&.sociability_high? || @personality&.sociability_very_high?
        base += 20
      elsif @personality&.sociability_low? || @personality&.sociability_very_low?
        base -= 20
      end

      case @state&.daily_whim
      when "chatty"        then base += 30
      when "quiet"         then base -= 30
      when "philosophical" then base += 40
      when "creative"      then base += 20
      end

      base -= 20 if @state&.physical == "tired" || @state&.physical == "sick"

      base = base.clamp(20, 140)
      "#{base}文字程度（必ず140文字以内）で書く。この人物らしい長さで"
    end

    def motivation_text
      labels = {
        venting:          "気持ちを吐き出したい",
        approval_seeking: "共感してほしい・いいねがほしい",
        connecting:       "誰かとつながりたい",
        sharing:          "面白い体験を共有したい",
        reacting:         "何かに反応したい",
        killing_time:     "暇つぶし",
        self_expressing:  "自分を表現したい",
        recording:        "今日の記録を残したい"
      }
      labels[@motivation[:primary]] || "暇つぶし"
    end
  end
end
