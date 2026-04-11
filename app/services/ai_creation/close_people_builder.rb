module AiCreation
  # プロフィール情報から家族・友人を LLM で生成する
  class ClosePeopleBuilder
    def self.build(profile_attrs)
      new(profile_attrs).build
    end

    def initialize(profile_attrs)
      @profile = profile_attrs
    end

    def build
      prompt = build_prompt
      raw = LlmClient.call(prompt, purpose: :creation, max_tokens: 1000)
      parse_response(raw)
    rescue => e
      Rails.logger.error("ClosePeopleBuilder LLM failed: #{e.message}")
      []
    end

    private

    def build_prompt
      <<~PROMPT
        以下のSNSユーザーの家族構成・人間関係を推測し、具体的な人物リストをJSON形式で返してください。

        ## ユーザー情報
        名前: #{@profile[:name]}
        年齢: #{@profile[:age]}歳
        性別: #{@profile[:gender]}
        職業: #{@profile[:occupation]}
        ライフステージ: #{@profile[:life_stage]}
        家族構成: #{@profile[:family_structure]}
        関係状況: #{@profile[:relationship_status]}
        子供の数: #{@profile[:num_children] || 0}人
        末子年齢: #{@profile[:youngest_child_age] ? "#{@profile[:youngest_child_age]}歳" : "不明"}
        経歴: #{@profile[:bio]}

        ## 出力形式（JSONのみ、配列）
        [
          {
            "name": "田村 奈緒",
            "relation": "spouse",
            "age": 41,
            "gender": "female",
            "notes": "看護師。穏やかで家庭的。"
          },
          {
            "name": "田村 健太",
            "relation": "child",
            "age": 10,
            "gender": "male",
            "notes": "小学4年生。サッカーが好き。"
          }
        ]

        ## ルール
        - relation は spouse/partner/child/parent/sibling/friend/colleague/other のいずれか
        - gender は male/female/other/unspecified のいずれか
        - 家族構成・ライフステージ・子供の数と整合性を取ること
        - 友人は1〜2人程度（職場や趣味つながり）
        - notes は一人ひとりの特徴を簡潔に（50字以内）
        - 年齢は現実的な範囲で設定すること
        - 人物が多すぎる場合は主要な人物のみ（最大6人）
        - 独身・一人暮らしの場合は友人1〜2人のみ
      PROMPT
    end

    def parse_response(raw)
      # ```json ... ``` ブロックを除去
      json_text = raw.gsub(/```json?\s*/i, "").gsub(/```/, "").strip
      people = JSON.parse(json_text)
      return [] unless people.is_a?(Array)

      people.filter_map do |p|
        relation = p["relation"].to_s
        next unless AiClosePerson.relations.key?(relation)

        gender = p["gender"].to_s
        gender = "unspecified" unless %w[male female other_gender unspecified].include?(gender)
        # LLMが"other"を返す場合の対応
        gender = "other_gender" if gender == "other"

        age = p["age"]&.to_i
        age = nil if age && !(0..120).include?(age)

        {
          name:          p["name"].to_s.presence || "名無し",
          relation:      relation,
          age:           age,
          age_base_date: age ? Date.current : nil,
          gender:        gender,
          notes:         p["notes"]&.truncate(100)
        }
      end
    rescue JSON::ParserError => e
      Rails.logger.error("ClosePeopleBuilder parse failed: #{e.message}")
      []
    end
  end
end
