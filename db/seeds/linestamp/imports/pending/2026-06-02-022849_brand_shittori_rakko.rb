# frozen_string_literal: true

# しっとり労りラッコ (shittori_rakko)
# Research: weekly_trends_2026_w23 idea A 由来。
# コンセプト: 梅雨どきの不調や疲れに、やわらかい敬語で先回りして寄り添うラッコ。

Linestamp::Importer.run(seed_id: "2026-06-02-022849_brand_shittori_rakko") do
  brand = upsert_brand!(
    slug: "shittori_rakko",
    character_name: "しっとり労りラッコ",
    series_name: "しっとり労りラッコの梅雨ケア敬語",
    persona_name: "しっとり労りラッコ",
    concept: "梅雨の低気圧や疲れが気になる時期に、やわらかい敬語で相手を気づかうケア特化のラッコキャラクター",
    target_audience: "20〜30代の働くユーザーと、その同僚・友人・家族。体調や気分を気づかいながら短文でやり取りしたい層",
    description: "梅雨のしんどさに寄り添う短文敬語を、濡れつや感のあるラッコで届けるブランド",
    primary_color: "#7EC9C3",
    research_slug: "weekly_trends_2026_w23",
    two_part_definition: "しっとり労りラッコは「ただ濡れてかわいいラッコ」ではない。しっとり労りラッコは、相手の不調や疲れを先回りしてやわらかな敬語で休息を促し、会話の温度を下げずに安心を返す梅雨ケア特化の相棒だ。",
    character_parts: {
      eyes: "黒目がちのたれ目、小さなハイライト入り",
      mouth: "小さくやわらかなへの字寄りの微笑み",
      ears: "丸く小さい耳、頭の左右に控えめ",
      body: "しっとり丸みのあるラッコ体型、2.5頭身",
      limbs: "短い前足でそっと包み込むような仕草を取る",
      tail: "幅広でやわらかく反ったラッコの尾",
      collar: "首元の水滴型ケアタグ(全構図で必ず描くシグネチャ)"
    },
    font_spec: {
      primary: "丸ゴシックやや太め",
      color: "#355C5A",
      outline: "white_thick_4px"
    },
    tone_axes: { gentle: 0.95, cute: 0.78, neat: 0.64 },
    target_axes: {
      age: %w[age_20s age_30s],
      gender: %w[unisex],
      occupation: %w[office_worker]
    },
    identity_axes: {
      silhouette: "濡れた毛並みを感じる、丸く縦長のラッコ輪郭",
      signature: "首元の水滴型ケアタグを全構図で必ず描く",
      signature_color: "#7EC9C3",
      voice: "やわらかい敬語で短文、命令形を避ける",
      behavior: "相手の不調に先回りして休息を促す",
      desire_weakness: "相手に無理をさせたくなくて、つい先回りして気づかってしまう"
    },
    base_compositions: [
      "正面・微笑み",
      "正面・心配顔",
      "正面・おじぎ",
      "横向き立ち",
      "座り・湯のみ持ち",
      "寝そべり",
      "両手を胸元で重ねる",
      "片手をそっと差し出す",
      "しっぽを抱える",
      "ブランケットにくるまる",
      "小さく手を振る",
      "上目づかい"
    ]
  )

  attach_communication_themes!(brand, %w[
    encouragement
    appreciation_for_effort
    need_break
    gratitude
    apology
    status_busy
    greeting_night
    agreement
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute neat],
    motif: %w[animal],
    demographic: %w[age_20s age_30s business_user unisex],
    setting: %w[remote_work office home with_friends with_family]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "梅雨の労り敬語8選",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "雨音が続く季節でも、相手のしんどさに先回りして、短い敬語でそっと安心を返す",
    usage_scenes: %w[remote_work office home],
    target_emotions: %w[安心 労り ぬくもり],
    communication_themes: %w[encouragement appreciation_for_effort need_break gratitude apology status_busy greeting_night agreement],
    attributes: {
      tone: %w[gentle neat],
      setting: %w[remote_work office home]
    },
    stamps: [
      {
        label: "お大事にです",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle], setting: %w[home remote_work] },
        situation: "相手が体調不良やだるさを伝えてくれたとき",
        intent: "無理せず休んでほしい気持ちを伝える",
        pose_spec: "正面・心配顔・片手をそっと差し出す",
        props: "なし",
        usage_scene: "不調共有への返信",
        communication_purpose: "やさしく背中を押す労り",
        search_keywords: %w[お大事 体調不良 労り]
      },
      {
        label: "ご無理なくです",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break encouragement],
        attributes: { tone: %w[gentle neat], setting: %w[office remote_work] },
        situation: "相手が忙しそうで休めていないとき",
        intent: "休憩を取ってほしいと伝える",
        pose_spec: "両手を胸元で重ねる",
        props: "湯のみ",
        usage_scene: "残業や詰まり気味の相談",
        communication_purpose: "休息提案をやわらかく伝える",
        search_keywords: %w[無理しないで 休憩 気遣い]
      },
      {
        label: "ありがとうございます",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude appreciation_for_effort],
        attributes: { tone: %w[gentle neat], setting: %w[office home] },
        situation: "相手が助けてくれた直後",
        intent: "丁寧に感謝する",
        pose_spec: "正面・おじぎ",
        props: "なし",
        usage_scene: "フォローや共有への返答",
        communication_purpose: "温度のある丁寧なお礼",
        search_keywords: %w[ありがとう 感謝 お礼]
      },
      {
        label: "おつかれさまです",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "業務終わりや一区切りで声をかけるとき",
        intent: "頑張りをねぎらう",
        pose_spec: "正面・微笑み・小さく手を振る",
        props: "なし",
        usage_scene: "退勤前後の挨拶",
        communication_purpose: "労力を認めて安心させる",
        search_keywords: %w[おつかれ ねぎらい 退勤]
      },
      {
        label: "すみませんです",
        primary_communication_theme: "apology",
        communication_themes: %w[apology],
        attributes: { tone: %w[gentle neat], setting: %w[office home] },
        situation: "軽いミスや遅れを詫びたいとき",
        intent: "角を立てずに謝る",
        pose_spec: "上目づかい・おじぎ",
        props: "なし",
        usage_scene: "ちょっとした謝罪",
        communication_purpose: "謝罪の圧を和らげる",
        search_keywords: %w[すみません 謝罪 ミス]
      },
      {
        label: "立てこんでおります",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy],
        attributes: { tone: %w[neat], setting: %w[office remote_work] },
        situation: "すぐに返せない状況を共有したいとき",
        intent: "忙しさを丁寧に伝える",
        pose_spec: "横向き立ち・しっぽを抱える",
        props: "資料束",
        usage_scene: "返信遅れの事前共有",
        communication_purpose: "冷たく見せず状況を伝える",
        search_keywords: %w[取り込み中 忙しい 返信遅れ]
      },
      {
        label: "今夜はゆっくりで",
        primary_communication_theme: "greeting_night",
        communication_themes: %w[greeting_night encouragement],
        attributes: { tone: %w[gentle cute], setting: %w[home with_family] },
        situation: "夜の終わりに相手を気づかいたいとき",
        intent: "休息を促す夜の挨拶をする",
        pose_spec: "ブランケットにくるまる",
        props: "ブランケット",
        usage_scene: "就寝前のメッセージ",
        communication_purpose: "夜に安心感を残す",
        search_keywords: %w[おやすみ 夜 ゆっくり]
      },
      {
        label: "それは大変でしたね",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement encouragement],
        attributes: { tone: %w[gentle], setting: %w[with_friends home office] },
        situation: "相手の苦労話や不調に共感するとき",
        intent: "まず受け止める",
        pose_spec: "正面・心配顔・両手を胸元で重ねる",
        props: "なし",
        usage_scene: "相談や愚痴への返答",
        communication_purpose: "共感を先に置いて安心させる",
        search_keywords: %w[共感 大変でしたね 受け止め]
      }
    ]
  )
end
