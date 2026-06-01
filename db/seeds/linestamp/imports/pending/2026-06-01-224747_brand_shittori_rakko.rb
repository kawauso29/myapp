# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-224747_brand_shittori_rakko") do
  brand = upsert_brand!(
    slug: "shittori_rakko",
    character_name: "しっとり労りラッコ（しっとりいたわりらっこ）",
    persona_name: "雨の日の不調をやわらか敬語で受け止める寄り添いラッコ",
    concept: "梅雨本番のだるさや低気圧不調に、短文で気遣いと回復行動を返せる",
    series_name: "しっとり労りラッコの雨の日ことば",
    target_audience: "梅雨時の体調変化を気づかい合いたい20〜40代",
    research_slug: "weekly_trends_2026_w23",
    primary_color: "#6FA8DC",
    two_part_definition: "雨粒柄のケープをまとったラッコが、低気圧のしんどさに共感して回復の一手を丁寧に添えるケア特化キャラ。",
    character_parts: {
      eyes: "うるんだ楕円の黒目で、まぶたが少し下がった安心感のある目",
      mouth: "小さく弧を描く口元で、やさしく語りかける微笑み",
      ears: "丸く小さい耳に淡い水色の内側",
      body: "ふっくら楕円のラッコ体型で胸元に白いふわ毛",
      limbs: "短い前足を胸の前でそっと合わせる所作",
      tail: "体に沿って見える短めの扁平な尾",
      collar: "雨粒刺繍のネイビーケープ"
    },
    font_spec: {
      primary: "rounded_maru",
      color: "#2F4858",
      outline: "#FFFFFF"
    },
    tone_axes: {
      softness: 0.94,
      friendliness: 0.84,
      excitement: 0.28,
      calmness: 0.88
    },
    target_axes: {
      age: "20s-40s",
      lifestyle: "rainy_season_workers",
      usage_context: "rainy_day_condition_care"
    },
    identity_axes: {
      silhouette: "丸い頭と胸前で手を合わせる楕円体の小柄ラッコシルエット",
      name_origin: "『しっとり(梅雨の空気)』+『労り(体調気づかい)』を合わせた和語ネーミング",
      desire_weakness: "誰かの不調を見過ごしたくないが、自分も湿気で動きがゆっくりになる",
      signature_color: "雨雲ネイビー #2F4858 と霧水色 #6FA8DC の二色軸",
      signature: "雨粒刺繍ケープと胸前で手を合わせる仕草で『まず労る』を示す",
      voice: "やわらか敬語を基調に、1文目で共感・2文目で小さな回復行動を添える",
      behavior: "不調を否定せず受け止め、休息・水分・体温調整の次アクションへ橋渡しする"
    }
  )

  attach_communication_themes!(brand, %w[greeting_morning need_break appreciation_for_effort encouragement gratitude status_busy])
  attach_attribute_values!(brand, {
    tone: %w[gentle neat],
    demographic: %w[age_20s age_30s unisex],
    setting: %w[home remote_work office]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "梅雨本番の体調気づかいを短文で返す労りセット",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "雨音のある部屋で、しんどい気分を受け止めながら整えていく",
    usage_scenes: %w[morning_checkin work_break evening_recovery],
    target_emotions: %w[安心 共感 回復],
    communication_themes: %w[greeting_morning need_break appreciation_for_effort encouragement gratitude status_busy],
    attributes: {
      tone: %w[gentle],
      setting: %w[home remote_work office]
    },
    stamps: [
      {
        label: "おはよう、無理せずいきましょう",
        primary_communication_theme: "greeting_morning",
        search_keywords: %w[おはよう 梅雨 気遣い]
      },
      {
        label: "気圧つらい日ですね",
        primary_communication_theme: "need_break",
        search_keywords: %w[低気圧 頭痛 つらい]
      },
      {
        label: "そのだるさ、わかります",
        primary_communication_theme: "encouragement",
        search_keywords: %w[共感 だるい しんどい]
      },
      {
        label: "温かい飲み物にしましょう",
        primary_communication_theme: "need_break",
        search_keywords: %w[温活 飲み物 休憩]
      },
      {
        label: "今日も本当におつかれさまです",
        primary_communication_theme: "appreciation_for_effort",
        search_keywords: %w[労い おつかれ 仕事]
      },
      {
        label: "少し横になってくださいね",
        primary_communication_theme: "need_break",
        search_keywords: %w[休息 横になる 体調]
      },
      {
        label: "ゆっくりで大丈夫ですよ",
        primary_communication_theme: "encouragement",
        search_keywords: %w[励まし 安心 ゆっくり]
      },
      {
        label: "落ち着いたらまた連絡ください",
        primary_communication_theme: "status_busy",
        search_keywords: %w[連絡 後で 待っています]
      }
    ]
  )
end
