module Daily
  # 翌日の日次スケジュールをLLMで生成するサービス
  # 生成されたスケジュールは ai_daily_schedules テーブルに保存される
  class DailyScheduleGenerator
    def self.generate(ai_user, target_date: Date.tomorrow)
      new(ai_user, target_date).generate
    end

    def initialize(ai_user, target_date)
      @ai = ai_user
      @profile = ai_user.ai_profile
      @personality = ai_user.ai_personality
      @target_date = target_date
      @today_state = ai_user.ai_daily_states.find_by(date: Date.current)
    end

    def generate
      # 既存のスケジュールがあれば削除（再生成）
      existing = @ai.ai_daily_schedules.find_by(scheduled_date: @target_date)
      existing&.destroy

      prompt = build_prompt
      raw = call_llm(prompt)
      result = parse_response(raw)

      @ai.ai_daily_schedules.create!(
        scheduled_date: @target_date,
        items:          result[:items],
        week_context:   result[:week_context],
        tomorrow_note:  result[:tomorrow_note]
      )
    rescue => e
      Rails.logger.error("[DailyScheduleGenerator] Failed for ai_id=#{@ai.id}: #{e.class} #{e.message}")
      # フォールバック: 基本スケジュールを生成
      create_default_schedule
    end

    private

    def build_prompt
      wday_label = %w[日曜日 月曜日 火曜日 水曜日 木曜日 金曜日 土曜日][@target_date.wday]
      season = case @target_date.month
               when 3..5 then "春"
               when 6..8 then "夏"
               when 9..11 then "秋"
               else "冬"
               end

      state_desc = if @today_state
        "今日の体調=#{@today_state.physical}, 気分=#{@today_state.mood}, 忙しさ=#{@today_state.busyness}"
      else
        "今日の状態不明"
      end

      <<~PROMPT
        以下の人物の#{@target_date.strftime('%Y年%m月%d日')}（#{wday_label}・#{season}）の
        リアルなタイムスケジュールをJSONで生成してください。

        ## 人物情報
        名前: #{@profile&.name}
        年齢: #{@profile&.age}歳
        職業: #{@profile&.occupation}（#{occupation_type_label}）
        趣味: #{@profile&.hobbies&.first(3)&.join('、') || 'なし'}
        生活ステージ: #{life_stage_label}

        ## 性格
        社交性: #{level_label(@personality&.sociability)}
        忍耐力: #{level_label(@personality&.patience)}
        好奇心: #{level_label(@personality&.curiosity)}

        ## 今日の状態（前日）
        #{state_desc}

        ## ルール
        - 6〜25時の範囲で8〜14個の予定を作る
        - 職業・生活スタイルに合ったリアルな予定にする
        - 曜日を考慮する（#{wday_label}）
        - mood_impact: 楽しい・好きな予定は+1〜+15、嫌いな予定は-1〜-15、普通は0
        - energy_cost: その予定に必要なエネルギー（0〜30）
        - is_cancellable: 急遽キャンセルできる予定かどうか
        - 特別なイベントや小さなハプニングを1〜2個入れる

        ## 出力形式（JSONのみ、他の文字は一切出力しない）
        {
          "items": [
            {
              "hour": 7,
              "end_hour": 8,
              "activity": "起床・朝食",
              "location": "自宅",
              "mood_impact": 2,
              "energy_cost": 5,
              "is_done": false,
              "is_cancellable": false,
              "note": "今日は早起きできた"
            }
          ],
          "week_context": "今週は期末試験前で少し緊張している。週末に友達と遊ぶ約束がある。",
          "tomorrow_note": "明日はレッスンがあるので早起きしなきゃ"
        }
      PROMPT
    end

    def call_llm(prompt)
      LlmClient.call(prompt, purpose: :creation, max_tokens: 2000)
    end

    def parse_response(raw)
      json = JSON.parse(raw)

      items = (json["items"] || []).map do |item|
        {
          "hour"          => item["hour"].to_i.clamp(0, 25),
          "end_hour"      => item["end_hour"]&.to_i&.clamp(0, 26),
          "activity"      => item["activity"].to_s.truncate(30),
          "location"      => item["location"].to_s.truncate(20),
          "mood_impact"   => item["mood_impact"].to_i.clamp(-20, 20),
          "energy_cost"   => item["energy_cost"].to_i.clamp(0, 30),
          "is_done"       => false,
          "is_cancellable" => item["is_cancellable"] == true,
          "note"          => item["note"].to_s.truncate(50)
        }
      end.sort_by { |item| item["hour"] }

      {
        items:         items,
        week_context:  json["week_context"].to_s.truncate(200),
        tomorrow_note: json["tomorrow_note"].to_s.truncate(100)
      }
    end

    def create_default_schedule
      items = default_items_for(@profile&.occupation_type, @target_date.wday)
      @ai.ai_daily_schedules.create!(
        scheduled_date: @target_date,
        items:          items,
        week_context:   nil,
        tomorrow_note:  nil
      )
    end

    def default_items_for(occupation_type, wday)
      is_weekend = [ 0, 6 ].include?(wday)
      base = [
        { "hour" => 7,  "end_hour" => 8,  "activity" => "起床・朝食", "location" => "自宅",   "mood_impact" => 0, "energy_cost" => 5,  "is_done" => false, "is_cancellable" => false, "note" => "" },
        { "hour" => 12, "end_hour" => 13, "activity" => "昼食",       "location" => "自宅",   "mood_impact" => 3, "energy_cost" => 5,  "is_done" => false, "is_cancellable" => false, "note" => "" },
        { "hour" => 22, "end_hour" => 23, "activity" => "就寝準備",   "location" => "自宅",   "mood_impact" => 0, "energy_cost" => 3,  "is_done" => false, "is_cancellable" => false, "note" => "" }
      ]

      unless is_weekend
        case occupation_type&.to_s
        when "student"
          base.insert(1, { "hour" => 9, "end_hour" => 16, "activity" => "学校", "location" => "学校", "mood_impact" => 0, "energy_cost" => 20, "is_done" => false, "is_cancellable" => false, "note" => "" })
        when "employed"
          base.insert(1, { "hour" => 9, "end_hour" => 18, "activity" => "仕事", "location" => "職場", "mood_impact" => 0, "energy_cost" => 25, "is_done" => false, "is_cancellable" => false, "note" => "" })
        end
      end

      base
    end

    def level_label(val)
      AiPersonality::LEVEL_LABELS[val&.to_sym] || "普通"
    end

    def occupation_type_label
      {
        "employed"         => "会社員",
        "freelance"        => "フリーランス",
        "student"          => "学生",
        "unemployed"       => "無職",
        "other_occupation" => "その他"
      }[@profile&.occupation_type] || "不明"
    end

    def life_stage_label
      {
        "student"      => "学生",
        "single"       => "社会人・独身",
        "couple"       => "カップル",
        "parent_young" => "子育て中（乳幼児）",
        "parent_school" => "子育て中（学童）",
        "parent_adult" => "子育て中（成人）",
        "senior"       => "シニア"
      }[@profile&.life_stage] || "不明"
    end
  end
end
