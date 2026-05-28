# frozen_string_literal: true

# Brand + 初回 Pack(8 stamps) を 1 ファイルで投入する Importer DSL の雛形。
# File: db/seeds/linestamp/imports/pending/{YYYY-MM-DD-HHMMSS}_brand_{slug}.rb
#
# 注意:
#   - 1 ブランド = 1 ファイル = Brand + 初回 Pack(stamps 8 枚) を必ず同梱する。
#   - プロンプト系カラム(brand_prompt / sheet_prompt / stamp.prompt) は書かない。
#     レコード作成時の after_commit で自動合成される。
#   - 各 stamp の primary_communication_theme は、Brand に紐づけた slug を使う。
#   - 追加で Pack を増やしたい場合は pack_template.rb を使って別ファイルで投入する。

Linestamp::Importer.run(seed_id: "REPLACE_WITH_UNIQUE_ID") do
  # --- Brand 本体 ---
  brand = upsert_brand!(
    slug: "my_brand",
    character_name: "キャラ名",
    series_name: "シリーズ名",
    persona_name: "ペルソナ名",
    concept: "ブランドコンセプト",
    target_audience: "ターゲット層の説明",
    description: "ブランド説明",
    primary_color: "#RRGGBB",
    background_color_for_gen: "#RRGGBB"
  )

  attach_communication_themes!(brand, %w[
    greeting_morning
    gratitude
    appreciation_for_effort
    encouragement
    quick_answer
    need_break
    apology
    agreement
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute],
    motif: %w[animal],
    demographic: %w[age_20s age_30s unisex],
    setting: %w[home remote_work office]
  })

  # --- 初回 Pack(必ず 8 stamps) ---
  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "シリーズのテーマ(例: 在宅ワークの日常)",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "シリーズの世界観(任意)",
    usage_scenes: %w[remote_work home],
    target_emotions: %w[安心 共感 労り],
    communication_themes: %w[greeting_morning gratitude],
    attributes: {
      tone: %w[gentle],
      setting: %w[remote_work home]
    },
    stamps: [
      {
        label: "おはよう",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning],
        attributes: { tone: %w[gentle], setting: %w[remote_work] },
        situation: "1日の始まりの挨拶",
        intent: "やわらかく1日を始める",
        pose_spec: "正面・うっすら笑顔・軽く手を振る",
        props: "なし",
        usage_scene: "朝の業務開始連絡",
        communication_purpose: "返信負担を増やさず温度を伝える"
      },
      {
        label: "おつかれ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "業務終了時のねぎらい",
        intent: "相手の頑張りを肯定する",
        pose_spec: "正面・微笑み",
        props: "なし",
        usage_scene: "業務終了 / 退勤時",
        communication_purpose: "短文でねぎらいを伝える"
      },
      {
        label: "ありがとう",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "助けてもらったとき",
        intent: "感謝を素直に伝える",
        pose_spec: "両手を合わせるおじぎ",
        props: "なし",
        usage_scene: "相手の協力を受けたとき",
        communication_purpose: "形式的にならない感謝表現"
      },
      {
        label: "了解",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer],
        attributes: { tone: %w[gentle], setting: %w[office] },
        situation: "依頼や連絡を受けたとき",
        intent: "短く受領を伝える",
        pose_spec: "サムズアップ",
        props: "なし",
        usage_scene: "業務チャット即レス",
        communication_purpose: "返信負担を最小化"
      },
      {
        label: "わかる",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[gentle], setting: %w[home with_friends] },
        situation: "相手の話に共感したいとき",
        intent: "共感を即座に返す",
        pose_spec: "頷き",
        props: "なし",
        usage_scene: "雑談・愚痴の聞き役",
        communication_purpose: "言葉にしづらい共感を伝える"
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
        communication_purpose: "謝罪のハードルを下げる"
      },
      {
        label: "ちょっと休憩",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break],
        attributes: { tone: %w[gentle], setting: %w[remote_work home] },
        situation: "離席や休憩を伝えるとき",
        intent: "離席を角を立てず共有",
        pose_spec: "マグカップを抱える",
        props: "マグカップ",
        usage_scene: "中抜け・離席連絡",
        communication_purpose: "状況共有を簡潔に"
      },
      {
        label: "がんばろう",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "相手を励ましたいとき",
        intent: "前向きに背中を押す",
        pose_spec: "両手で小さくガッツポーズ",
        props: "なし",
        usage_scene: "週明け / 大事な場面の前",
        communication_purpose: "押しつけがましくない励まし"
      }
    ]
  )
end
