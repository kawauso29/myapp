# frozen_string_literal: true

# しっとり労りラッコ (shittori_rakko)
# Research: weekly_trends_2026_w23 (梅雨本番・低気圧ケアと短文気づかい需要) idea A を起点。

Linestamp::Importer.run(seed_id: "2026-06-01-224734_brand_shittori_rakko") do
  brand = upsert_brand!(
    research_slug: "weekly_trends_2026_w23",
    slug: "shittori_rakko",
    character_name: "しっとり労りラッコ",
    series_name: "しっとり労りラッコの梅雨気づかい",
    persona_name: "しっとり労りラッコ",
    concept: "梅雨のだるさや低気圧不調に寄り添い、短文のやわらかい敬語で相手をいたわるラッコの連絡ブランド",
    target_audience: "20〜40代の働く世代と家族・友人、体調や移動の気づかいを角を立てずに伝えたい人",
    description: "雨の日の体調気づかい、移動連絡、ねぎらいをやさしい温度で返せる実用系スタンプブランド",
    primary_color: "#6FA8B7",
    two_part_definition: "しっとり労りラッコは「ただ雨の日に沈むだけの動物」ではない、低気圧でしんどい日に相手の体調と都合を短文敬語でそっと支える連絡上手なラッコである。",
    character_parts: {
      eyes: "たれ目ぎみの小さな黒目、眠そうでも穏やか",
      mouth: "小さな口で口角だけやわらかく上がる",
      ears: "小さく丸い耳",
      body: "雨粒型のふっくら2.5頭身",
      limbs: "短い前脚と小さな後脚、指は省略",
      tail: "幅広の平たい尾",
      collar: "細い水色のケアタグ付き首輪"
    },
    font_spec: {
      primary: "丸ゴシック太め",
      color: "#2F4F5A",
      outline: "white_thick_4px"
    },
    tone_axes: { gentle: 0.96, neat: 0.62, cute: 0.48 },
    target_axes: {
      age: %w[age_20s age_30s age_40s],
      gender: %w[unisex],
      occupation: %w[business_user]
    },
    identity_axes: {
      signature: "胸元の水滴型ケアタグを全構図で必ず描く",
      voice: "やわらかい敬語で短文、命令形を避ける",
      behavior: "相手の不調に先回りして休息を促す"
    },
    base_compositions: [
      "正面・無表情",
      "正面・うっすら笑顔",
      "正面・困り顔",
      "正面・真顔",
      "横向き立ち",
      "寝そべり",
      "座り",
      "雨粒を見上げる",
      "両手合わせ",
      "軽く手を振る",
      "小さなおじぎ",
      "サムズアップ"
    ]
  )

  attach_communication_themes!(brand, %w[
    appreciation_for_effort
    encouragement
    quick_answer
    on_the_way
    confirm_meetup
    need_break
    gratitude
    apology
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle neat],
    motif: %w[animal],
    demographic: %w[age_20s age_30s age_40s business_user unisex],
    setting: %w[remote_work office home with_family]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "梅雨本番の体調気づかい連絡",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "雨音の中でも相手を急かさず、短文敬語で体調と移動を気づかう",
    usage_scenes: %w[remote_work office home with_family],
    target_emotions: %w[安心 共感 労り],
    communication_themes: %w[appreciation_for_effort encouragement quick_answer on_the_way confirm_meetup need_break gratitude apology],
    attributes: {
      tone: %w[gentle neat],
      setting: %w[remote_work office home]
    },
    stamps: [
      {
        label: "お大事にです",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "相手が体調不良を伝えたとき",
        intent: "やさしく休養を促す",
        pose_spec: "正面・うっすら笑顔・小さなおじぎ",
        props: "なし",
        usage_scene: "体調気づかいの返信",
        communication_purpose: "短文でいたわりを伝える",
        search_keywords: %w[お大事 体調不良 労り]
      },
      {
        label: "無理せずで",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break encouragement],
        attributes: { tone: %w[gentle], setting: %w[remote_work office] },
        situation: "忙しそうな相手に声をかけるとき",
        intent: "休憩を後押しする",
        pose_spec: "座り・両手合わせ",
        props: "湯のみ",
        usage_scene: "進行中の業務チャット",
        communication_purpose: "休む提案を角なく伝える",
        search_keywords: %w[無理しない 休憩 ひといき]
      },
      {
        label: "到着しました",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way confirm_meetup],
        attributes: { tone: %w[neat], setting: %w[office with_family] },
        situation: "待ち合わせ場所に着いたとき",
        intent: "到着を正確に共有する",
        pose_spec: "横向き立ち・軽く手を振る",
        props: "折りたたみ傘",
        usage_scene: "待ち合わせ連絡",
        communication_purpose: "移動完了を簡潔に伝える",
        search_keywords: %w[到着 待ち合わせ 移動]
      },
      {
        label: "少し遅れます",
        primary_communication_theme: "apology",
        communication_themes: %w[apology on_the_way],
        attributes: { tone: %w[neat gentle], setting: %w[office with_family] },
        situation: "雨で移動が遅れたとき",
        intent: "遅延を丁寧に共有する",
        pose_spec: "正面・困り顔・小さなおじぎ",
        props: "しずく",
        usage_scene: "移動遅延連絡",
        communication_purpose: "相手の不安を減らす",
        search_keywords: %w[遅れます 遅延 雨]
      },
      {
        label: "確認ありがとうございます",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude quick_answer],
        attributes: { tone: %w[neat], setting: %w[remote_work office] },
        situation: "確認返信をもらったとき",
        intent: "丁寧にお礼を返す",
        pose_spec: "正面・うっすら笑顔・両手合わせ",
        props: "なし",
        usage_scene: "業務の確認スレッド",
        communication_purpose: "形式を保って感謝を伝える",
        search_keywords: %w[確認 感謝 返信]
      },
      {
        label: "了解です",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer],
        attributes: { tone: %w[neat], setting: %w[remote_work office] },
        situation: "依頼内容を受領したとき",
        intent: "即時に受領を伝える",
        pose_spec: "正面・真顔・サムズアップ",
        props: "なし",
        usage_scene: "業務チャットの即レス",
        communication_purpose: "対応可能を明確化する",
        search_keywords: %w[了解 即レス 受領]
      },
      {
        label: "おつかれさまです",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle neat], setting: %w[office remote_work] },
        situation: "作業が一段落したとき",
        intent: "相手の頑張りをねぎらう",
        pose_spec: "正面・うっすら笑顔",
        props: "なし",
        usage_scene: "業務終了前後",
        communication_purpose: "労力への敬意を短文で返す",
        search_keywords: %w[おつかれ ねぎらい 退勤]
      },
      {
        label: "体調いかがですか",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup encouragement],
        attributes: { tone: %w[gentle], setting: %w[home with_family] },
        situation: "天候悪化時に様子をうかがうとき",
        intent: "相手の体調を気づかう",
        pose_spec: "雨粒を見上げる・心配顔",
        props: "小さなタオル",
        usage_scene: "家族や同僚への安否確認",
        communication_purpose: "負担をかけず近況を確認する",
        search_keywords: %w[体調 気づかい 様子]
      }
    ]
  )
end
