module AiAction
  class ReplyPromptBuilder
    RELATIONSHIP_TONE = {
      stranger:     "丁寧語で礼儀正しく。初対面の相手に話しかけるように",
      acquaintance: "少しフレンドリーに。敬語ベースだが固すぎない",
      friend:       "タメ口でカジュアルに。気軽な友達同士の会話",
      close_friend: "親密な内輪感。略語・あだ名・冗談もOK"
    }.freeze

    def self.build(ai_user, target_post)
      new(ai_user, target_post).build
    end

    def initialize(ai_user, target_post)
      @ai = ai_user
      @profile = ai_user.ai_profile
      @personality = ai_user.ai_personality
      @state = ai_user.today_state
      @target_post = target_post
      @target_ai = target_post.ai_user
      @target_profile = @target_ai.ai_profile
      @relationship = find_relationship
    end

    def build
      <<~PROMPT
        あなたは以下の人物です。他の人のSNS投稿にリプライしてください。

        ## あなたのプロフィール
        名前: #{@profile.name}
        年齢: #{@profile.age}歳
        職業: #{@profile.occupation}
        居住地: #{@profile.location}
        自己紹介: #{@profile.bio}

        ## あなたの好み・特性
        #{preferences_section}

        ## あなたの性格（核パラメータ）
        #{core_personality_section}

        ## 今日の状態
        #{today_state_section}

        #{memory_section}

        ## リプライ先の投稿
        投稿者: #{@target_profile.name}（#{@target_profile.age}歳、#{@target_profile.occupation}）
        内容: #{@target_post.content}

        ## この人との関係
        関係性: #{relationship_label}
        #{relationship_memory_section}

        ## リプライのルール
        - 50文字以内が自然（最大100文字）
        - トーン: #{tone_instruction}
        - 日本語で書く
        - 本物の人間のリプライとして自然に書く
        - AIであることを示唆する表現は絶対に使わない
        - 「リプライします」などのメタ発言はしない
        - 敬語・タメ口は年齢と関係性に合わせる

        ## 出力形式（JSON、他の文字は一切出力しない）
        {
          "content": "リプライ本文（50文字以内推奨、最大100文字）",
          "reaction_type": "empathy | question | agree | disagree | joke | cheer",
          "tags": ["タグ1"]
        }
      PROMPT
    end

    private

    def find_relationship
      AiRelationship.find_by(ai_user_id: @ai.id, target_ai_user_id: @target_ai.id)
    end

    def preferences_section
      parts = []
      parts << "趣味: #{@profile.hobbies.first(3).join('、')}" if @profile.hobbies.any?
      parts << "大切にしていること: #{@profile.values.first(3).join('、')}" if @profile.values.any?
      parts << "口癖: #{@profile.catchphrase}" if @profile.catchphrase.present?
      parts.join("\n")
    end

    def core_personality_section
      {
        sociability:       @personality.to_prompt_hash[:sociability],
        empathy:           @personality.to_prompt_hash[:empathy],
        emotional_range:   @personality.to_prompt_hash[:emotional_range],
        self_expression:   @personality.to_prompt_hash[:self_expression]
      }.map { |k, v| "#{k}: #{v}" }.join("\n")
    end

    def today_state_section
      return "状態不明" unless @state

      parts = []
      parts << "気分: #{@state.mood}"
      parts << "今日の気まぐれ: #{@state.daily_whim}"
      parts << "飲酒中（レベル#{@state.drinking_level}/3）" if @state.is_drinking
      parts.join("\n")
    end

    def memory_section
      sections = []

      long_term = @ai.ai_long_term_memories.order(importance: :desc, occurred_on: :desc).limit(3)
      if long_term.any?
        sections << "## あなたの記憶（重要な出来事）\n" +
                    long_term.map { |m| "- #{m.occurred_on}: #{m.content}" }.join("\n")
      end

      short_term = @ai.ai_short_term_memories
                      .where("expires_at > ?", Time.current)
                      .order(created_at: :desc).limit(2)
      if short_term.any?
        sections << "## 最近の出来事\n" + short_term.map(&:content).join("\n")
      end

      sections.join("\n\n")
    end

    def relationship_label
      return "知らない人（stranger）" unless @relationship

      {
        stranger:     "知らない人（stranger）",
        acquaintance: "顔見知り（acquaintance）",
        friend:       "友達（friend）",
        close_friend: "親友（close_friend）"
      }[@relationship.relationship_type.to_sym] || "知らない人（stranger）"
    end

    def relationship_memory_section
      return "" unless @relationship

      memory = AiRelationshipMemory.find_by(
        ai_user_id: @ai.id,
        target_ai_user_id: @target_ai.id
      )
      return "" unless memory

      "最近のやりとり: #{memory.summary}"
    end

    def tone_instruction
      rel_type = @relationship&.relationship_type&.to_sym || :stranger
      RELATIONSHIP_TONE[rel_type] || RELATIONSHIP_TONE[:stranger]
    end
  end
end
