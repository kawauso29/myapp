module Events
  # 年間イベント管理サービス
  # `config/events.yml` に定義されたイベントキーに対して
  # 日本語ラベル・投稿ヒント・テーママッピングを提供する。
  class EventCalendar
    # ---- イベントの日本語ラベル ----------------------------------------
    EVENT_LABELS = {
      "new_year"          => "お正月",
      "setsubun"          => "節分",
      "valentine"         => "バレンタインデー",
      "hinamatsuri"       => "ひな祭り",
      "fiscal_year_end"   => "年度末",
      "new_season"        => "新年度・新生活",
      "childrens_day"     => "こどもの日",
      "tanabata"          => "七夕",
      "obon"              => "お盆",
      "halloween"         => "ハロウィン",
      "shichigosan"       => "七五三",
      "christmas_eve"     => "クリスマスイブ",
      "new_year_eve"      => "大晦日",
      "payday"            => "給料日",
      "cherry_blossom"    => "お花見シーズン",
      "sports_day_season" => "スポーツの秋",
      "bonus_summer"      => "夏のボーナスシーズン",
      "bonus_winter"      => "冬のボーナスシーズン"
    }.freeze

    # ---- 投稿ヒント（一般テキスト、または relationship_status で分岐する Hash） ----
    EVENT_POST_HINTS = {
      "new_year"       => "新年の抱負、初詣、おせち料理、年明けの気持ちなどを自然に盛り込む",
      "setsubun"       => "豆まき、恵方巻、鬼退治など節分の話題を自然に盛り込む",
      "valentine"      => {
        coupled: "パートナーへのチョコや特別な過ごし方など、ロマンチックな話題を自然に盛り込む",
        single:  "義理チョコ、友チョコ、手作り菓子、またはバレンタインへの複雑な気持ちを自然に盛り込む"
      },
      "hinamatsuri"    => "ひな人形、ちらし寿司、桃の節句など春の到来を感じる話題を自然に盛り込む",
      "fiscal_year_end" => "年度末の忙しさ、引き継ぎ、異動・卒業への気持ちなどを自然に盛り込む",
      "new_season"     => "新生活の始まり、新しい目標、フレッシュな気持ちを自然に盛り込む",
      "childrens_day"  => "こどもの日、鯉のぼり、柏餅など初夏の話題を自然に盛り込む",
      "tanabata"       => "七夕の願いごと、星空、短冊など夏の情緒ある話題を自然に盛り込む",
      "obon"           => "お盆休み、帰省、先祖への思い、夏の終わりを感じる話題を自然に盛り込む",
      "halloween"      => "仮装、パーティ、お菓子、ハロウィン飾りなど楽しい雰囲気を自然に盛り込む",
      "shichigosan"    => "子供の成長、七五三の着物、秋の行楽など晩秋の話題を自然に盛り込む",
      "christmas_eve"  => {
        coupled: "パートナーとのクリスマスの過ごし方、プレゼント、ロマンチックな雰囲気を自然に盛り込む",
        single:  "友人とのクリスマス、一人クリスマス、ケーキやチキンなど食べ物の話題を自然に盛り込む"
      },
      "new_year_eve"   => "大晦日の振り返り、年越しそば、紅白、来年への期待などを自然に盛り込む",
      "payday"         => "給料日の解放感、ご褒美、欲しいもの、外食などを自然に盛り込む",
      "cherry_blossom" => "お花見、桜、春の訪れ、花見弁当、花見スポットなど春らしい話題を自然に盛り込む",
      "sports_day_season" => "スポーツ観戦、運動会、秋の行楽、食欲の秋など秋らしい話題を自然に盛り込む",
      "bonus_summer"   => "夏のボーナス、ご褒美、旅行、欲しいものなどを自然に盛り込む",
      "bonus_winter"   => "冬のボーナス、年末の買い物、帰省の準備などを自然に盛り込む"
    }.freeze

    # ---- イベントキー → pending_post_theme enum 値のマッピング -----------
    # nil は「テーマ設定なし・プロンプトヒントのみで多様化」
    EVENT_THEME_MAP = {
      "new_year"          => "new_hobby",
      "setsubun"          => nil,
      "valentine"         => "new_relationship",
      "hinamatsuri"       => nil,
      "fiscal_year_end"   => nil,
      "new_season"        => "skill_up",
      "childrens_day"     => nil,
      "tanabata"          => nil,
      "obon"              => nil,
      "halloween"         => "new_hobby",
      "shichigosan"       => nil,
      "christmas_eve"     => "new_relationship",
      "new_year_eve"      => nil,
      "payday"            => nil,
      "cherry_blossom"    => "new_hobby",
      "sports_day_season" => "new_hobby",
      "bonus_summer"      => nil,
      "bonus_winter"      => nil
    }.freeze

    # イベントキーの日本語ラベルを返す
    def self.label_for(event_key)
      EVENT_LABELS[event_key.to_s] || event_key.to_s
    end

    # イベントキーに対応する投稿ヒントを返す
    # ai_user が渡された場合はカップル/シングルで分岐する
    def self.post_hint_for(event_key, ai_user: nil)
      hint = EVENT_POST_HINTS[event_key.to_s]
      return nil unless hint

      return hint if hint.is_a?(String)

      coupled = coupled_profile?(ai_user)
      coupled ? hint[:coupled] : hint[:single]
    end

    # イベントキーに対応する pending_post_theme を返す
    # valentine / christmas_eve はカップルのみ関係系テーマを適用する
    def self.theme_for(event_key, ai_user: nil)
      key = event_key.to_s
      theme = EVENT_THEME_MAP[key]
      return nil unless theme

      if %w[valentine christmas_eve].include?(key) && theme == "new_relationship"
        return nil unless coupled_profile?(ai_user)
      end

      theme
    end

    # 複数のイベントキーに対してラベル・ヒントを付与した配列を返す
    # ラベルが存在するイベントのみ含める
    def self.enriched_events_for(event_keys, ai_user: nil)
      known_keys = event_keys.select { |key| EVENT_LABELS.key?(key.to_s) }
      known_keys.map do |key|
        { key: key, label: label_for(key), hint: post_hint_for(key, ai_user: ai_user) }
      end
    end

    # ---- private --------------------------------------------------------
    def self.coupled_profile?(ai_user)
      profile = ai_user&.ai_profile
      return false unless profile

      profile.relationship_status_in_relationship? || profile.relationship_status_married?
    end
    private_class_method :coupled_profile?
  end
end
