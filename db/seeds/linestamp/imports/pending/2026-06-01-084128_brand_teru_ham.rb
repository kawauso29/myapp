# frozen_string_literal: true

# Brand + 初回 Pack(8 stamps) — 秒レスてるてるハム
# 起点 Research: weekly_trends_2026_w23（梅雨本番・低気圧ケアと短文気づかい需要）
# 企画案 B: 『秒レスてるてるハム』: 1〜5文字中心の超短文で、業務/私用どちらも崩れない。

Linestamp::Importer.run(seed_id: "2026-06-01-084128_brand_teru_ham") do
  # --- Brand 本体 ---
  brand = upsert_brand!(
    research_slug: "weekly_trends_2026_w23",

    slug: "teru_ham",
    character_name: "てるてるハム",
    series_name: "秒レスてるてるハムのひとこと便",
    persona_name: "てるハム",
    concept: "てるてる坊主のように丸くて白く、1〜5文字の超短文で雨の日もさっと会話をつなぐハムスター。業務連絡も私用チャットも崩れない短文センスが持ち味。",
    target_audience: "20〜30代のビジネス層・在宅勤務者。チャットの返信が早く、文字数は最小限で済ませたい人。",
    description: "「了解」「ありがとう」「休憩」を1〜5文字でぽんと返せるてるてる坊主型ハムスター。雨の日のだるさも短文パンチで軽くする秒レス特化ブランド。",
    primary_color: "#B8D8E8",

    two_part_definition: "ただ丸くてかわいいハムスターではない。てるてる坊主のように短く丸く、1〜5文字で雨の日も会話をつなぐ秒レス特化の相棒だ。",

    character_parts: {
      eyes:   "大きめの丸目・黒目いっぱい・ポジティブな輝き",
      mouth:  "小さな点状の口、笑う時はUの字に広がる",
      ears:   "小さな丸耳が頭頂左右にちょこんと出る",
      body:   "てるてる坊主のように下膨れの丸い球体、2頭身弱",
      limbs:  "極短い手足・指はなし・ぷらぷら感がある",
      tail:   "極小の丸しっぽ・背面にほぼ隠れる",
      collar: "首元にてるてる結びの白いリボン（全構図必須）"
    },

    font_spec: {
      primary: "丸ゴシック太め",
      color:   "#2D5F8A",
      outline: "white_thick_3px"
    },

    tone_axes:   { cute: 0.9, gentle: 0.65, funny: 0.5 },
    target_axes: {
      age:        %w[age_20s age_30s],
      gender:     %w[unisex],
      occupation: %w[business_user]
    },

    identity_axes: {
      silhouette:      "てるてる坊主のような逆涙型の丸いシルエット・極短手足が左右に少し出る・黒塗りでも即識別できる",
      name_origin:     "『てるてるハム』= てるてる坊主の丸さ・晴れを祈る前向きさ + ハムスターの短文スピード感。読み: てるてるはむ",
      signature:       "首元のてるてる結び白リボン（全構図・全スタンプで必ず描く）",
      signature_color: "淡い空色 #B8D8E8 をベース主役色として占有（雨あがりうさぎの青 #8EC5FC と異なる彩度・明度）",
      desire_weakness: "求める: 即時コミュニケーション・返信の速さ / 苦手: 長文・説明・待たせること",
      voice:           "1〜5文字で完結する超短文。断定的だが圧迫感がなく、どんな相手にも通じる",
      behavior:        "返信前にその場でくるっと1回転する（高速返信のルーティン）"
    },

    base_compositions: [
      "正面・無表情",
      "正面・うっすら笑顔",
      "正面・困り顔",
      "正面・拳を挙げガッツポーズ",
      "横向き立ち",
      "両手広げお辞儀",
      "その場でくるっと回転中",
      "ぱたぱた走り"
    ]
  )

  attach_communication_themes!(brand, %w[
    greeting_morning
    greeting_night
    quick_answer
    agreement
    gratitude
    apology
    status_busy
    need_break
    appreciation_for_effort
    encouragement
  ])

  attach_attribute_values!(brand, {
    tone:        %w[cute gentle funny],
    motif:       %w[animal],
    demographic: %w[age_20s age_30s business_user unisex],
    setting:     %w[remote_work office home with_friends]
  })

  # --- 初回 Pack(8 stamps) ---
  create_pack!(
    brand:             brand,
    slug:              "pack_001",
    series_theme:      "秒レス日常ひとこと便",
    position:          1,
    layer:             "core_work",
    purchase_unit_size: 8,
    world_view:        "雨の日も晴れの日も、1〜5文字でスパッと会話をつなぐ日常",
    usage_scenes:      %w[remote_work office home with_friends],
    target_emotions:   %w[安心 共感 スピード感],
    communication_themes: %w[quick_answer gratitude agreement appreciation_for_effort],
    attributes: {
      tone:    %w[cute gentle],
      setting: %w[remote_work office home]
    },
    stamps: [
      {
        label:                      "おはよ",
        primary_communication_theme: "greeting_morning",
        communication_themes:        %w[greeting_morning],
        attributes:                  { tone: %w[cute], setting: %w[remote_work office] },
        situation:                   "朝の業務開始・チャット一番乗り",
        intent:                      "1文字の余計もなく朝の温度を届ける",
        pose_spec:                   "正面・うっすら笑顔・軽く手を振る",
        props:                       "なし",
        usage_scene:                 "朝のチャット開始時",
        communication_purpose:       "返信負担ゼロで朝の存在感を伝える",
        search_keywords:             %w[おはよう 朝 業務開始 挨拶]
      },
      {
        label:                      "了解",
        primary_communication_theme: "quick_answer",
        communication_themes:        %w[quick_answer],
        attributes:                  { tone: %w[cute], setting: %w[office remote_work] },
        situation:                   "依頼・連絡を受けたとき即レス",
        intent:                      "2文字で確実に受領を伝える",
        pose_spec:                   "サムズアップ・拳を挙げる",
        props:                       "なし",
        usage_scene:                 "業務チャットの即時返信",
        communication_purpose:       "返信コストを最小化して会話を流す",
        search_keywords:             %w[了解 OK 確認 即レス]
      },
      {
        label:                      "わかる",
        primary_communication_theme: "agreement",
        communication_themes:        %w[agreement],
        attributes:                  { tone: %w[cute gentle], setting: %w[home with_friends] },
        situation:                   "相手の話に共感したいとき",
        intent:                      "3文字の共感で会話の温度を保つ",
        pose_spec:                   "正面・大きく頷き",
        props:                       "なし",
        usage_scene:                 "雑談・愚痴の聞き役",
        communication_purpose:       "言葉にしにくい共感を即座に返す",
        search_keywords:             %w[わかる 共感 それな 相槌]
      },
      {
        label:                      "ありがと",
        primary_communication_theme: "gratitude",
        communication_themes:        %w[gratitude],
        attributes:                  { tone: %w[cute gentle], setting: %w[office home] },
        situation:                   "助けてもらったとき・何かしてもらったとき",
        intent:                      "4文字の感謝を軽やかに届ける",
        pose_spec:                   "両手広げお辞儀・リボンが揺れる",
        props:                       "なし",
        usage_scene:                 "相手の協力後の素直な感謝",
        communication_purpose:       "形式的にならない感謝表現",
        search_keywords:             %w[ありがとう 感謝 お礼 助かった]
      },
      {
        label:                      "ごめん",
        primary_communication_theme: "apology",
        communication_themes:        %w[apology],
        attributes:                  { tone: %w[gentle], setting: %w[office home] },
        situation:                   "軽いミスや遅延を詫びるとき",
        intent:                      "3文字で謝罪のハードルを下げる",
        pose_spec:                   "正面・困り顔・頭をかく",
        props:                       "なし",
        usage_scene:                 "返信遅れや小さなミスの謝罪",
        communication_purpose:       "重くなりすぎず関係をリセット",
        search_keywords:             %w[ごめん 謝罪 すみません 遅れ]
      },
      {
        label:                      "休憩",
        primary_communication_theme: "need_break",
        communication_themes:        %w[need_break],
        attributes:                  { tone: %w[cute], setting: %w[remote_work home] },
        situation:                   "離席・休憩を手短に伝えるとき",
        intent:                      "2文字で離席を角を立てず共有",
        pose_spec:                   "その場でくるっと回転中・離席サイン",
        props:                       "なし",
        usage_scene:                 "中抜け・離席連絡",
        communication_purpose:       "状況共有を最小文字で済ませる",
        search_keywords:             %w[休憩 離席 中抜け ちょっと待って]
      },
      {
        label:                      "おつかれ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes:        %w[appreciation_for_effort],
        attributes:                  { tone: %w[gentle cute], setting: %w[office remote_work] },
        situation:                   "業務終了・退勤時のねぎらい",
        intent:                      "4文字のねぎらいで1日をしめる",
        pose_spec:                   "正面・うっすら笑顔・軽く手を振る",
        props:                       "なし",
        usage_scene:                 "退勤時・業務終了の一言",
        communication_purpose:       "短文でぬくもりを残す",
        search_keywords:             %w[おつかれ ねぎらい 退勤 お疲れ様]
      },
      {
        label:                      "がんばろ",
        primary_communication_theme: "encouragement",
        communication_themes:        %w[encouragement],
        attributes:                  { tone: %w[cute funny], setting: %w[office remote_work with_friends] },
        situation:                   "相手や自分に向けて背中を押したいとき",
        intent:                      "4文字で軽やかに前向きさを届ける",
        pose_spec:                   "正面・拳を挙げガッツポーズ",
        props:                       "なし",
        usage_scene:                 "週明け・大事な場面の前・雨の日の気分転換",
        communication_purpose:       "押しつけがましくない励まし",
        search_keywords:             %w[がんばろ 応援 励まし 前向き]
      }
    ]
  )
end
