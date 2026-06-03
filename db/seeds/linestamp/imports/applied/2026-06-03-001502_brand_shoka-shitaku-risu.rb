# frozen_string_literal: true

# ブランド「初夏したくリス」 — 由来: weekly_trends_2026_w24 brand_idea C
# 衣替え・身支度・生活リズム整えを前向きに後押し。体より大きいふさふさ尾＋丸ほっぺが識別点。
# 既存ブランドと シルエット(大きい尾の小動物)・シグネチャ(尾+したくエプロン)・色(アプリコット #E8915B)で被らない。
# ※ 緑系(kimochi_kaeru)との色被りを避けるため primary_color は初夏のアプリコット橙にしている。

Linestamp::Importer.run(seed_id: "2026-06-03-001502_brand_shoka-shitaku-risu") do
  brand = upsert_brand!(
    slug: "shoka_shitaku_risu",
    character_name: "したくリス（シタクリス）",
    series_name: "初夏のしたく",
    persona_name: "衣替えを楽しむ準備上手",
    concept: "衣替え・身支度・生活リズム整えを前向きに後押しするリス。“はじめる前のひと支度”を楽しみに変える。",
    target_audience: "10〜30代・学生〜若手社会人。初夏の生活リズムを整えたい層。朝の挨拶や軽い外出・食の誘いをよく使う人。",
    description: "体より大きいふさふさの尾と、木の実を頬張る丸ほっぺが目印の小柄なリス。小さなしたくエプロンを着け、何かを始める前に頬袋から道具を出して支度する。明るく前向きでテンポがよい。",
    primary_color: "#E8915B",
    research_slug: "weekly_trends_2026_w24",
    two_part_definition: "ただ準備するリスではない。初夏のしたくを“楽しみ”に変える準備上手だ。",
    character_parts: {
      eyes: "ぱっちり丸く前向き。キラッと光る",
      mouth: "前歯がちらりと見えるにっこり口",
      ears: "ぴんと立った三角。先に房毛",
      body: "小柄でまるっこい。木の実で頬がふくらむ",
      limbs: "細い手足。両手で道具や木の実を持つ",
      tail: "体より大きいふさふさの尾（最大の識別点）",
      collar: "小さなしたくエプロン／手ぬぐい（シグネチャ）"
    },
    font_spec: {
      primary: "元気な丸ゴシック",
      color: "#E8915B",
      outline: "白＋若葉の差し色"
    },
    tone_axes: {
      warmth: "高（親しみ）",
      formality: "低（カジュアル）",
      energy: "高（明るく前向き）"
    },
    target_axes: {
      age: "10〜30代・学生〜若手",
      relationship: "友人×ゆるい職場",
      usage: "朝の挨拶・身支度・軽い外出と食の誘い"
    },
    identity_axes: {
      silhouette: "体より大きいふさふさ尾＋丸ほっぺの輪郭。黒塗りでも“尾の大きい小動物”と分かる（最重要）",
      signature: "大きな尾 ＋ したくエプロン ＋ 木の実",
      signature_color: "#E8915B（初夏のアプリコット橙）",
      voice: "明るく前向き、テンポよい",
      behavior: "何かを始める前に頬袋から道具を出して支度する",
      desire_weakness: "準備しすぎて荷物（木の実）が増える",
      name_origin: "「支度（したく）」＋リス"
    },
    base_compositions: [
      "エプロン姿で手を振る朝の支度ポーズ",
      "頬袋から道具を取り出して身支度するポーズ",
      "木の実を抱えて外出に誘うポーズ"
    ]
  )

  attach_communication_themes!(brand, %w[
    greeting_morning
    encouragement
    meal_invitation
    confirm_meetup
    on_the_way
    agreement
    celebration
  ])

  attach_attribute_values!(brand, {
    tone: %w[cute gentle funny],
    motif: %w[animal food],
    demographic: %w[age_10s age_20s age_30s student unisex],
    setting: %w[home with_friends office remote_work]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "初夏のしたく はじめのひと支度",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "衣替えの済んだ明るい初夏。したくリスが小さなエプロンで身支度を整え、朝の挨拶や軽い外出・食の誘いを前向きに後押しする。",
    usage_scenes: %w[朝の挨拶 身支度 衣替え 軽い外出の誘い 食の誘い],
    target_emotions: %w[前向き 元気 わくわく 親しみ],
    communication_themes: %w[greeting_morning encouragement meal_invitation confirm_meetup on_the_way agreement celebration],
    attributes: {
      tone: %w[cute gentle funny],
      motif: %w[animal food],
      demographic: %w[age_10s age_20s age_30s student unisex],
      setting: %w[home with_friends office remote_work]
    },
    stamps: [
      {
        label: "おはよ！したくOK",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning encouragement],
        attributes: { tone: %w[cute funny], motif: %w[animal], demographic: %w[age_10s age_20s student], setting: %w[home] },
        situation: "朝の挨拶・出発前",
        intent: "明るく一日のスタートを切る",
        pose_spec: "エプロン姿で手を振り、尾をぴんと立てる",
        props: "したくエプロン",
        usage_scene: "友人・家族の朝のチャット",
        communication_purpose: "元気な朝の挨拶",
        search_keywords: %w[おはよう 朝 支度 したくリス]
      },
      {
        label: "いっしょにがんばろ",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement agreement],
        attributes: { tone: %w[cute gentle], motif: %w[animal], demographic: %w[student unisex], setting: %w[with_friends office] },
        situation: "相手と一緒に物事を始めるとき",
        intent: "前向きに背中を押す",
        pose_spec: "両手で小さくガッツポーズ",
        props: "木の実",
        usage_scene: "勉強・仕事・部活の励まし",
        communication_purpose: "やる気を一緒に高める",
        search_keywords: %w[がんばろ 一緒に 応援 したくリス]
      },
      {
        label: "ごはん行かない？",
        primary_communication_theme: "meal_invitation",
        communication_themes: %w[meal_invitation confirm_meetup],
        attributes: { tone: %w[cute funny], motif: %w[animal food], demographic: %w[age_20s unisex], setting: %w[with_friends] },
        situation: "食事や外出に誘いたいとき",
        intent: "軽いノリで誘う",
        pose_spec: "木の実を差し出してにっこり誘う",
        props: "木の実 + お弁当包み",
        usage_scene: "週末手前のランチ・ごはんの誘い",
        communication_purpose: "気軽に食の誘いをかける",
        search_keywords: %w[ごはん 誘い ランチ したくリス]
      },
      {
        label: "いつ集合する？",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup agreement],
        attributes: { tone: %w[cute], motif: %w[animal], demographic: %w[age_20s student unisex], setting: %w[with_friends] },
        situation: "待ち合わせの相談",
        intent: "予定をテンポよく決める",
        pose_spec: "手帳とどんぐりペンを持って首をかしげる",
        props: "小さな手帳",
        usage_scene: "友人との集合時間調整",
        communication_purpose: "集合の確認を明るく取る",
        search_keywords: %w[集合 待ち合わせ 何時 したくリス]
      },
      {
        label: "もう出たよ〜",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way greeting_morning],
        attributes: { tone: %w[cute funny], motif: %w[animal], demographic: %w[unisex], setting: %w[with_friends] },
        situation: "移動を開始したとき",
        intent: "出発を元気に共有する",
        pose_spec: "尾をなびかせて駆け出す",
        props: "小さなリュック",
        usage_scene: "待ち合わせ前の進捗連絡",
        communication_purpose: "出発・到着見込みを伝える",
        search_keywords: %w[出発 向かってる もうすぐ したくリス]
      },
      {
        label: "りょうかい！",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement encouragement],
        attributes: { tone: %w[cute funny], motif: %w[animal], demographic: %w[age_10s age_20s student], setting: %w[with_friends office] },
        situation: "依頼や提案を受けたとき",
        intent: "テンポよく快諾する",
        pose_spec: "ビシッと敬礼ポーズ、尾も立つ",
        props: "したくエプロン",
        usage_scene: "友人・職場の軽い返事",
        communication_purpose: "元気な同意",
        search_keywords: %w[りょうかい 了解 OK したくリス]
      },
      {
        label: "衣替え完了〜！",
        primary_communication_theme: "celebration",
        communication_themes: %w[celebration encouragement],
        attributes: { tone: %w[cute funny], motif: %w[animal], demographic: %w[unisex], setting: %w[home] },
        situation: "衣替え・片づけ・支度が終わったとき",
        intent: "小さな達成を一緒に喜ぶ",
        pose_spec: "畳んだ服の山の上で万歳",
        props: "畳んだ服 + 手ぬぐい",
        usage_scene: "初夏の身支度報告",
        communication_purpose: "達成感を共有する",
        search_keywords: %w[衣替え 完了 達成 したくリス 初夏]
      },
      {
        label: "さあ、はじめよ",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement greeting_morning],
        attributes: { tone: %w[cute gentle], motif: %w[animal], demographic: %w[student unisex], setting: %w[home remote_work] },
        situation: "何かを始める直前",
        intent: "支度を整えて前向きにスタート",
        pose_spec: "袖をまくり頬袋から道具を出す",
        props: "頬袋の道具一式",
        usage_scene: "勉強・仕事・家事の始め",
        communication_purpose: "始動の後押し",
        search_keywords: %w[はじめよ スタート やる気 したくリス]
      }
    ]
  )
end
