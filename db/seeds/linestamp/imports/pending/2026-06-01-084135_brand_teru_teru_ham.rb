# frozen_string_literal: true

# Brand + 初回 Pack(8 stamps) — てるてるハム
# 起点 Research: weekly_trends_2026_w23
# 企画案: B)『秒レスてるてるハム』を軸に A・D のケア要素を合成
#
# seed_id はファイル名（拡張子除く）と一致させる

Linestamp::Importer.run(seed_id: "2026-06-01-084135_brand_teru_teru_ham") do
  # --- Brand 本体 ---
  brand = upsert_brand!(
    research_slug: "weekly_trends_2026_w23",

    slug: "teru_teru_ham",
    character_name: "てるてるハム",
    series_name: "秒レスてるてるハムのひとこと帳",
    persona_name: "てるハム",
    concept: "てるてる坊主シルエットのハムスターが、1〜5文字の超短文で業務も私用も角を立てず即返せるキャラクター。梅雨の空を晴れに変えるような一言を届ける",
    target_audience: "20〜30代のビジネス層・在宅ワーカー。返信が多くて疲弊気味で、短く丁寧に即返ししたい人",
    description: "梅雨本番の忙しい季節でも、てるてる坊主のように願いを込めた超短文で会話を繋ぐ。長文不要・気持ちは十分伝わる即レス特化ブランド",
    primary_color: "#F0EAE0",

    two_part_definition: "てるてるハムはただかわいいハムスターではない。てるてるハムは、1〜5文字の超短文でも温度感を失わずに梅雨の会話を晴れに変える、即レスの小さな相棒だ。",

    character_parts: {
      eyes:   "小さな黒丸2点・やや離れて配置、どの角度でもシンプルに識別できる",
      mouth:  "小さなUの字・困り顔は逆U字・喜び顔は横に広がる",
      ears:   "頭上部にちょこんと出た小さな丸耳が2つ",
      body:   "てるてる坊主型の丸く膨らんだ胴体・2頭身・くすみホワイトの布をまとった輪郭",
      limbs:  "短い小さな手が両脇からちょこんと出る・足はほぼ体に隠れる",
      tail:   "",
      collar: "体上部に細い紐の結び目（てるてる坊主の吊り紐・全構図で必ず描く）"
    },

    font_spec: {
      primary: "丸ゴシック極太",
      color:   "#3A3333",
      outline: "white_thick_3px"
    },

    tone_axes: { cute: 0.9, gentle: 0.8, funny: 0.35 },

    target_axes: {
      age:        %w[age_20s age_30s],
      gender:     %w[unisex],
      occupation: %w[business_user]
    },

    identity_axes: {
      silhouette:      "てるてる坊主型の丸い胴体・頭上の小さな丸耳・2頭身。黒塗りシルエットでも『てるてる系ハム』と即識別できる",
      name_origin:     "『てるてる』= 晴れを願うてるてる坊主由来。『ハム』= ハムスター。読み: てるてるはむ",
      signature:       "体上部の細い紐の結び目（てるてる坊主の吊り紐）が全構図で必ず見える",
      signature_color: "くすみホワイト #F0EAE0 を主役色として占有。梅雨競合の青・水色・緑系と明確に差別化",
      desire_weakness: "求める: 即座に返せる安心感 / 苦手: 長文を考えること・沈黙が続く状況",
      voice:           "1〜5文字でも温度感が伝わる。業務でも崩れない丁寧さを超短文で体現",
      behavior:        "返信時にぷるぷると体を一振りして気持ちを込める"
    },

    base_compositions: [
      "正面・無表情",
      "正面・微笑み",
      "正面・困り顔",
      "横向き",
      "前傾み（急いでいる）",
      "両手を広げる",
      "体をぷるぷると振る",
      "小さくジャンプ",
      "しょんぼり",
      "頷き",
      "サムズアップ",
      "紐を持って吊り下がる"
    ]
  )

  attach_communication_themes!(brand, %w[
    quick_answer
    agreement
    gratitude
    appreciation_for_effort
    encouragement
    greeting_morning
    greeting_night
    on_the_way
    status_busy
    need_break
  ])

  attach_attribute_values!(brand, {
    tone:        %w[cute gentle funny],
    motif:       %w[animal],
    demographic: %w[age_20s age_30s unisex business_user],
    setting:     %w[remote_work office home with_friends]
  })

  # --- 初回 Pack（ちょうど 8 stamps・LINE 申請最小単位）---
  create_pack!(
    brand:             brand,
    slug:              "pack_001",
    series_theme:      "梅雨でも秒レス！てるてるハムのひとこと集",
    position:          1,
    layer:             "core_work",
    purchase_unit_size: 8,
    world_view:        "梅雨の忙しい季節に、てるてるハムの超短文が会話を晴れに変える",
    usage_scenes:      %w[remote_work office home with_friends],
    target_emotions:   %w[安心 即レス 気軽さ 共感 ねぎらい],
    communication_themes: %w[
      quick_answer
      gratitude
      appreciation_for_effort
      encouragement
      agreement
      greeting_morning
      on_the_way
      need_break
    ],
    attributes: {
      tone:    %w[cute gentle],
      setting: %w[remote_work office home with_friends]
    },
    stamps: [
      {
        label:                       "OK！",
        primary_communication_theme: "quick_answer",
        communication_themes:        %w[quick_answer],
        attributes:                  { tone: %w[cute gentle], setting: %w[office remote_work] },
        situation:                   "依頼や連絡をすぐ受領するとき",
        intent:                      "一言で受領を明確に伝える",
        pose_spec:                   "正面・微笑み・サムズアップ",
        props:                       "なし",
        usage_scene:                 "業務チャット・即レス",
        communication_purpose:       "返信負担を最小化しつつ意思疎通を確実に",
        search_keywords:             %w[OK 了解 即レス ビジネス]
      },
      {
        label:                       "りょうかい",
        primary_communication_theme: "quick_answer",
        communication_themes:        %w[quick_answer],
        attributes:                  { tone: %w[cute gentle], setting: %w[office remote_work home] },
        situation:                   "指示や依頼を受けたとき",
        intent:                      "ていねいに了承を返す",
        pose_spec:                   "前傾み・頷き",
        props:                       "なし",
        usage_scene:                 "業務連絡・チャット返信",
        communication_purpose:       "角が立たない受諾表現",
        search_keywords:             %w[りょうかい 了解 返事 承認]
      },
      {
        label:                       "ありがとう",
        primary_communication_theme: "gratitude",
        communication_themes:        %w[gratitude],
        attributes:                  { tone: %w[cute gentle], setting: %w[office remote_work home with_friends] },
        situation:                   "助けてもらったとき・お礼を言いたいとき",
        intent:                      "短くても気持ちが伝わる感謝",
        pose_spec:                   "両手を広げる・微笑み",
        props:                       "なし",
        usage_scene:                 "お礼・サポートへの反応",
        communication_purpose:       "重くならない感謝表現",
        search_keywords:             %w[ありがとう 感謝 お礼 助かった]
      },
      {
        label:                       "おつかれ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes:        %w[appreciation_for_effort],
        attributes:                  { tone: %w[cute gentle], setting: %w[office remote_work home] },
        situation:                   "業務終了時・頑張った相手へのねぎらい",
        intent:                      "短くねぎらいを届ける",
        pose_spec:                   "正面・微笑み・小さく手を振る",
        props:                       "なし",
        usage_scene:                 "退勤時・業務終了連絡",
        communication_purpose:       "ねぎらいのハードルを下げる",
        search_keywords:             %w[おつかれ お疲れ ねぎらい 退勤]
      },
      {
        label:                       "がんばろう",
        primary_communication_theme: "encouragement",
        communication_themes:        %w[encouragement],
        attributes:                  { tone: %w[cute gentle], setting: %w[office remote_work with_friends] },
        situation:                   "相手を励ましたいとき・週明けや大事な場面の前",
        intent:                      "押しつけがましくない前向きな背中押し",
        pose_spec:                   "小さくジャンプ・体をぷるぷると振る",
        props:                       "なし",
        usage_scene:                 "週明け・試験や発表前",
        communication_purpose:       "軽快な応援",
        search_keywords:             %w[がんばろう 応援 週明け 励まし]
      },
      {
        label:                       "おはよう",
        primary_communication_theme: "greeting_morning",
        communication_themes:        %w[greeting_morning],
        attributes:                  { tone: %w[cute gentle], setting: %w[remote_work office home] },
        situation:                   "1日の始まりの挨拶",
        intent:                      "やわらかく1日を開始する",
        pose_spec:                   "正面・微笑み・両手を広げる",
        props:                       "なし",
        usage_scene:                 "朝の業務開始・グループ挨拶",
        communication_purpose:       "返信不要で温度が伝わる朝挨拶",
        search_keywords:             %w[おはよう 朝 挨拶 業務開始]
      },
      {
        label:                       "今行くよ",
        primary_communication_theme: "on_the_way",
        communication_themes:        %w[on_the_way],
        attributes:                  { tone: %w[cute gentle], setting: %w[remote_work office with_friends] },
        situation:                   "移動中・到着前に伝えるとき",
        intent:                      "到着を手短に伝えて相手を安心させる",
        pose_spec:                   "前傾み（急いでいる）・小さく走る動作",
        props:                       "なし",
        usage_scene:                 "待ち合わせ・到着連絡",
        communication_purpose:       "遅延気味でも角が立たない到着予告",
        search_keywords:             %w[今行く 移動中 到着 待ち合わせ]
      },
      {
        label:                       "少し休憩",
        primary_communication_theme: "need_break",
        communication_themes:        %w[need_break],
        attributes:                  { tone: %w[cute gentle], setting: %w[remote_work home office] },
        situation:                   "離席や休憩を短く伝えるとき",
        intent:                      "角を立てずに休憩・離席を共有",
        pose_spec:                   "しょんぼり・体をぷるぷると振る",
        props:                       "なし",
        usage_scene:                 "中抜け・離席連絡",
        communication_purpose:       "状況共有を一言で済ませる",
        search_keywords:             %w[休憩 離席 中抜け ひとやすみ]
      }
    ]
  )
end
