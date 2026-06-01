# frozen_string_literal: true

# 秒レスてるてるハム (teru_ham)
# Research: weekly_trends_2026_w23 (梅雨本番・低気圧ケアと短文気づかい需要) idea B 由来。
# コンセプト: てるてる坊主シルエットのハムが 1〜5 文字の「秒レス」だけで気づかいを返す。
#            ビジネス/プライベート両用。シグネチャ = てるてる結びの白リボン。

Linestamp::Importer.run(seed_id: "2026-06-01-084128_brand_teru_ham") do
  brand = upsert_brand!(
    slug: "teru_ham",
    character_name: "秒レスてるてるハム",
    series_name: "秒レスてるてるハムの気づかい連絡",
    persona_name: "秒レスてるてるハム",
    concept: "梅雨の低気圧でだるい日でも、1〜5文字の秒レスで角を立てずに気づかいを返す在宅ワーク向けキャラクター",
    target_audience: "20〜30代の在宅/ハイブリッド勤務ユーザーと、その同僚・友人。返信は速くしたいが文面を考えるのは面倒な層",
    description: "短文(1〜5文字)に特化した報連相・相槌・ねぎらいを、てるてる坊主シルエットのハムで届けるブランド",
    primary_color: "#B8D8E8",
    research_slug: "weekly_trends_2026_w23",
    two_part_definition: "秒レスてるてるハムは「ただ丸くてかわいいハムスター」ではない。秒レスてるてるハムは、文面を練る余裕がない時に1〜5文字で角を立てず気持ちを返す、秒レス特化の相棒だ。",
    character_parts: {
      eyes: "小さな黒点目、やや眠そうだが穏やか",
      mouth: "小さな横線、笑う時も口角だけ少し上がる",
      ears: "丸く短いハムの耳、左右対称",
      body: "てるてる坊主型(上が丸く下が裾広がりの逆しずく)シルエットの2.5頭身",
      limbs: "短い手足、指は描き込まない",
      tail: "短く丸いしっぽ",
      collar: "てるてる結びの白リボン(首元、全構図で必ず描くシグネチャ)"
    },
    font_spec: {
      primary: "丸ゴシック太め",
      color: "#3A5A6B",
      outline: "white_thick_4px"
    },
    tone_axes: { cute: 0.9, gentle: 0.65, funny: 0.5 },
    target_axes: {
      age: %w[age_20s age_30s],
      gender: %w[unisex],
      occupation: %w[office_worker]
    },
    identity_axes: {
      silhouette: "逆しずく型(てるてる坊主)の黒シルエットで識別できる輪郭",
      signature: "てるてる結びの白リボン(全構図で必ず描く)",
      signature_color: "#B8D8E8",
      voice: "断定しない・1〜5文字で語尾までやわらかい",
      behavior: "低気圧の日はてるてる坊主らしく軽く揺れる仕草",
      desire_weakness: "速く返したいのに文面を考えるのが苦手で、つい短文になる"
    },
    base_compositions: [
      "正面・無表情",
      "正面・うっすら笑顔",
      "正面・困り顔",
      "正面・真顔",
      "横向き立ち",
      "寝そべり",
      "座り(マグ抱え)",
      "椅子に座る",
      "両手合わせ",
      "サムズアップ",
      "軽く手を振る",
      "頬杖"
    ]
  )

  attach_communication_themes!(brand, %w[
    greeting_morning
    quick_answer
    agreement
    gratitude
    apology
    need_break
    appreciation_for_effort
    encouragement
  ])

  attach_attribute_values!(brand, {
    tone: %w[cute gentle funny],
    motif: %w[animal],
    demographic: %w[age_20s age_30s business_user unisex],
    setting: %w[remote_work office home with_friends]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "梅雨の秒レス気づかい",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "低気圧でだるい梅雨でも、1〜5文字の秒レスで気持ちだけは軽く返す",
    usage_scenes: %w[remote_work office home],
    target_emotions: %w[安心 共感 労り],
    communication_themes: %w[greeting_morning quick_answer agreement gratitude apology need_break appreciation_for_effort encouragement],
    attributes: {
      tone: %w[cute gentle],
      setting: %w[remote_work office home]
    },
    stamps: [
      {
        label: "おはよ",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning],
        attributes: { tone: %w[gentle], setting: %w[remote_work] },
        situation: "1日の始まりの挨拶",
        intent: "やわらかく1日を始める",
        pose_spec: "正面・うっすら笑顔・軽く手を振る",
        props: "なし",
        usage_scene: "朝の業務開始連絡",
        communication_purpose: "返信負担ゼロで温度だけ伝える",
        search_keywords: %w[朝 おはよう 業務開始]
      },
      {
        label: "りょ",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer],
        attributes: { tone: %w[gentle funny], setting: %w[office] },
        situation: "依頼や連絡を受けたとき",
        intent: "最速で受領を伝える",
        pose_spec: "サムズアップ",
        props: "なし",
        usage_scene: "業務チャット即レス",
        communication_purpose: "返信負担を最小化(秒レス)",
        search_keywords: %w[了解 りょ OK]
      },
      {
        label: "それな",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[gentle funny], setting: %w[home with_friends] },
        situation: "相手の話に共感したいとき",
        intent: "共感を即座に返す",
        pose_spec: "頷き",
        props: "なし",
        usage_scene: "雑談・愚痴の聞き役",
        communication_purpose: "言葉にしづらい共感を一言で",
        search_keywords: %w[それな 共感 わかる]
      },
      {
        label: "あざす",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "助けてもらったとき",
        intent: "軽やかに感謝を伝える",
        pose_spec: "両手を合わせるおじぎ",
        props: "なし",
        usage_scene: "相手の協力を受けたとき",
        communication_purpose: "形式ばらない感謝表現",
        search_keywords: %w[ありがとう 感謝 あざす]
      },
      {
        label: "ごめん",
        primary_communication_theme: "apology",
        communication_themes: %w[apology],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "ミスや遅延を詫びるとき",
        intent: "重くなりすぎず詫びる",
        pose_spec: "頭をかく",
        props: "なし",
        usage_scene: "軽い謝罪",
        communication_purpose: "謝罪のハードルを下げる",
        search_keywords: %w[ごめん 謝罪 ミス]
      },
      {
        label: "休憩",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break],
        attributes: { tone: %w[gentle], setting: %w[remote_work home] },
        situation: "離席や休憩を伝えるとき",
        intent: "離席を角を立てず共有",
        pose_spec: "マグカップを抱える",
        props: "マグカップ",
        usage_scene: "中抜け・離席連絡",
        communication_purpose: "状況共有を簡潔に",
        search_keywords: %w[休憩 離席 中抜け]
      },
      {
        label: "おつ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle funny], setting: %w[office remote_work] },
        situation: "業務終了時のねぎらい",
        intent: "相手の頑張りを肯定する",
        pose_spec: "正面・微笑み",
        props: "なし",
        usage_scene: "業務終了 / 退勤時",
        communication_purpose: "短文でねぎらいを伝える",
        search_keywords: %w[おつかれ 退勤 ねぎらい]
      },
      {
        label: "ファイト",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle funny], setting: %w[office remote_work] },
        situation: "相手を励ましたいとき",
        intent: "前向きに背中を押す",
        pose_spec: "両手で小さくガッツポーズ",
        props: "なし",
        usage_scene: "週明け / 大事な場面の前",
        communication_purpose: "押しつけがましくない励まし",
        search_keywords: %w[ファイト 応援 励まし]
      }
    ]
  )
end
