module AiCreation
  class PersonalityGenerator
    LEVEL_KEYS = AiPersonality::LEVEL_ENUM.keys.freeze
    PURPOSE_KEYS = AiPersonality::PURPOSE_ENUM.keys.freeze

    def self.generate(profile_params)
      new(profile_params).generate
    end

    def initialize(profile_params)
      @name = profile_params[:name]
      @personality_note = profile_params[:personality_note] || ""
      @age = profile_params[:age]
      @occupation = profile_params[:occupation]
    end

    def generate
      prompt = build_prompt
      raw = call_llm(prompt)
      parse_response(raw)
    rescue => e
      Rails.logger.error("PersonalityGenerator failed: #{e.message}")
      default_personality
    end

    private

    def build_prompt
      sanitized_note = AiCreation::InputSanitizer.sanitize(@personality_note)

      <<~PROMPT
        以下の人物設定からSNSでの行動パラメータを推測してJSON形式で返してください。

        名前: #{@name}
        年齢: #{@age}
        職業: #{@occupation}
        人物設定: #{sanitized_note}

        各パラメータは1〜5の整数で返してください（1=非常に低い、3=普通、5=非常に高い）。

        ## 出力形式（JSONのみ、他の文字は一切出力しない）
        {
          "sociability": 3,
          "post_frequency": 3,
          "active_time_peak": 3,
          "need_for_approval": 3,
          "emotional_range": 3,
          "risk_tolerance": 3,
          "self_expression": 3,
          "drinking_frequency": 2,
          "self_esteem": 3,
          "empathy": 3,
          "jealousy": 2,
          "curiosity": 3,
          "follow_philosophy": 1,
          "primary_purpose": 0,
          "secondary_purpose": null
        }

        follow_philosophyは1〜5:
        1=気軽にフォロー 2=厳選 3=返報性重視 4=慎重 5=フォロワー増やしたい

        primary_purposeは0〜7:
        0=情報収集 1=承認欲求 2=仲間づくり 3=日記 4=面白い発信 5=愚痴吐き 6=見るだけ 7=インフルエンサー
      PROMPT
    end

    def call_llm(prompt)
      LlmClient.call(prompt, purpose: :creation, max_tokens: 500)
    end

    def parse_response(raw)
      json = JSON.parse(raw)
      attrs = {}

      # Level params (1-5)
      %w[sociability post_frequency active_time_peak need_for_approval
         emotional_range risk_tolerance self_expression drinking_frequency
         self_esteem empathy jealousy curiosity].each do |key|
        val = json[key].to_i.clamp(1, 5)
        attrs[key.to_sym] = LEVEL_KEYS[val - 1]
      end

      # Follow philosophy (1-5)
      fp = json["follow_philosophy"].to_i.clamp(1, 5)
      attrs[:follow_philosophy] = %i[casual selective reciprocal cautious collector][fp - 1]

      # Purpose (0-7)
      pp_val = json["primary_purpose"].to_i.clamp(0, 7)
      attrs[:primary_purpose] = PURPOSE_KEYS[pp_val]

      if json["secondary_purpose"]
        sp_val = json["secondary_purpose"].to_i.clamp(0, 7)
        attrs[:secondary_purpose] = PURPOSE_KEYS[sp_val]
      end

      attrs
    end

    def default_personality
      {
        sociability: :normal, post_frequency: :normal, active_time_peak: :normal,
        need_for_approval: :normal, emotional_range: :normal, risk_tolerance: :normal,
        self_expression: :normal, drinking_frequency: :low, self_esteem: :normal,
        empathy: :normal, jealousy: :low, curiosity: :normal,
        follow_philosophy: :casual, primary_purpose: :self_recorder,
        secondary_purpose: nil
      }
    end
  end
end
