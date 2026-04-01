module AiAction
  class DmPromptBuilder
    def self.build(sender:, recipient:, thread: nil, trigger: nil)
      new(sender: sender, recipient: recipient, thread: thread, trigger: trigger).build
    end

    def initialize(sender:, recipient:, thread:, trigger:)
      @sender = sender
      @sender_profile = sender.ai_profile
      @sender_personality = sender.ai_personality
      @sender_state = sender.today_state
      @recipient = recipient
      @recipient_profile = recipient.ai_profile
      @thread = thread
      @trigger = trigger
    end

    def build
      <<~PROMPT
        あなたは以下の人物です。SNSのDM（ダイレクトメッセージ）を送ってください。

        ## あなたのプロフィール
        名前: #{@sender_profile.name}
        年齢: #{@sender_profile.age}歳
        職業: #{@sender_profile.occupation}
        居住地: #{@sender_profile.location}
        自己紹介: #{@sender_profile.bio}

        ## あなたの性格
        #{personality_section}

        ## 今日のあなたの状態
        #{today_state_section}

        ## 送信先の相手
        名前: #{@recipient_profile.name}
        年齢: #{@recipient_profile.age}歳
        職業: #{@recipient_profile.occupation}
        自己紹介: #{@recipient_profile.bio}

        #{relationship_section}

        #{thread_history_section}

        ## DMを送る理由
        #{trigger_text}

        ## 絶対に守ること
        - 日本語で書く
        - 100文字以内
        - 本物の人間同士のDMとして自然に書く
        - AIであることを示唆する表現は絶対に使わない
        - 「送信します」などのメタ発言はしない
        - 敬語・タメ口は年齢差と関係性に合わせる
        - 相手との関係性に合った距離感で書く

        ## 出力形式（JSON、他の文字は一切出力しない）
        {
          "content": "DM本文（100文字以内）",
          "dm_type": "greeting|continuation|confession|advice|chitchat|comfort"
        }
      PROMPT
    end

    private

    def personality_section
      @sender_personality.to_prompt_hash.map { |k, v| "#{k}: #{v}" }.join("\n")
    end

    def today_state_section
      return "（状態情報なし）" unless @sender_state

      parts = []
      parts << "体調: #{@sender_state.physical}"
      parts << "気分: #{@sender_state.mood}"
      parts << "忙しさ: #{@sender_state.busyness}"
      parts << "飲酒中（レベル#{@sender_state.drinking_level}/3）" if @sender_state.is_drinking
      parts << "今日の気まぐれ: #{@sender_state.daily_whim}"
      parts.join("\n")
    end

    def relationship_section
      rel = AiRelationship.find_by(ai_user: @sender, target_ai_user: @recipient)
      return "" unless rel

      section = "## 相手との関係性\n"
      section += "関係: #{relationship_label(rel.relationship_type)}\n"
      section += "親密度スコア: #{rel.interaction_score}\n"

      memory = AiRelationshipMemory.find_by(ai_user: @sender, target_ai_user: @recipient)
      if memory
        section += "\n## 相手との思い出\n#{memory.summary}"
      end

      section
    end

    def relationship_label(type)
      {
        "stranger" => "知らない人",
        "acquaintance" => "知り合い",
        "friend" => "友達",
        "close_friend" => "親友"
      }[type] || type
    end

    def thread_history_section
      return "" unless @thread

      messages = @thread.ai_dm_messages.order(created_at: :desc).limit(5).reverse
      return "" if messages.empty?

      history = messages.map do |msg|
        sender_name = msg.ai_user_id == @sender.id ? "あなた" : @recipient_profile.name
        "#{sender_name}: #{msg.content}"
      end.join("\n")

      "## これまでの会話（直近5件）\n#{history}"
    end

    def trigger_text
      return @trigger if @trigger.present?

      if @thread.present?
        "相手からのメッセージに返信する（会話の続き）"
      else
        "初めてDMを送る（挨拶・きっかけ作り）"
      end
    end
  end
end
