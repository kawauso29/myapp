module AiCreation
  class ProfileBuilder
    def self.build(profile_params, personality_note:)
      new(profile_params, personality_note: personality_note).build
    end

    def initialize(profile_params, personality_note:)
      @params = AiCreation::InputSanitizer.sanitize_profile_params(profile_params)
      @personality_note = personality_note
    end

    def build
      if detailed_mode?
        build_detailed
      else
        build_from_llm
      end
    end

    private

    def detailed_mode?
      @params[:age].present? && @params[:occupation].present?
    end

    def build_detailed
      attrs = @params.slice(
        :name, :age, :gender, :occupation, :occupation_type, :location, :bio,
        :life_stage, :family_structure, :num_children, :youngest_child_age,
        :relationship_status, :favorite_foods, :favorite_music, :hobbies,
        :favorite_places, :strengths, :weaknesses, :values,
        :disliked_personality_types, :catchphrase
      )
      attrs[:personality_note] = @personality_note
      attrs
    end

    def build_from_llm
      prompt = build_prompt
      raw = call_llm(prompt)
      parse_response(raw)
    rescue => e
      Rails.logger.error("ProfileBuilder LLM failed: #{e.message}")
      build_default
    end

    def build_prompt
      sanitized_note = AiCreation::InputSanitizer.sanitize(@personality_note)

      <<~PROMPT
        以下の人物設定から、SNSのプロフィール情報を推測してJSON形式で返してください。

        名前: #{@params[:name]}
        人物設定: #{sanitized_note}

        ## 出力形式（JSONのみ）
        {
          "age": 24,
          "gender": "female",
          "occupation": "カフェ店員",
          "occupation_type": "employed",
          "location": "Tokyo",
          "bio": "コーヒーとカメラが好き。",
          "life_stage": "single",
          "family_structure": "alone",
          "relationship_status": "single",
          "favorite_foods": ["ラーメン", "チョコ"],
          "hobbies": ["カメラ", "散歩"],
          "values": ["自由", "友人"],
          "catchphrase": "まあいっか"
        }

        gender: male/female/other/unspecified
        occupation_type: employed/freelance/student/unemployed/other_occupation
        life_stage: student/single/couple/parent_young/parent_school/parent_adult/senior
        family_structure: alone/with_partner/nuclear/single_parent/extended
        relationship_status: single/in_relationship/married/divorced
      PROMPT
    end

    def call_llm(prompt)
      LlmClient.call(prompt, purpose: :creation, max_tokens: 800)
    end

    def parse_response(raw)
      json = JSON.parse(raw)
      {
        name: @params[:name],
        age: json["age"].to_i.clamp(10, 100),
        gender: json["gender"],
        occupation: json["occupation"],
        occupation_type: json["occupation_type"],
        location: json["location"],
        bio: json["bio"]&.truncate(100),
        life_stage: json["life_stage"],
        family_structure: json["family_structure"],
        relationship_status: json["relationship_status"],
        favorite_foods: Array(json["favorite_foods"]).first(5),
        hobbies: Array(json["hobbies"]).first(5),
        values: Array(json["values"]).first(5),
        catchphrase: json["catchphrase"],
        personality_note: @personality_note
      }
    end

    def build_default
      {
        name: @params[:name],
        age: 25,
        gender: :unspecified,
        occupation: "会社員",
        occupation_type: :employed,
        location: "Tokyo",
        bio: "",
        life_stage: :single,
        family_structure: :alone,
        relationship_status: :single,
        personality_note: @personality_note
      }
    end
  end
end
