# frozen_string_literal: true

# Brand: しっとり労りラッコ
# Research 起点: weekly_trends_2026_w23（梅雨本番・低気圧ケアと短文気づかい需要）
# Brand idea A: 『しっとり労りラッコ』 — 雨の日の体調気づかい・ねぎらいを柔らかい敬語で返せる。

Linestamp::Importer.run(seed_id: "2026-06-01-084121_brand_shittori_rakko") do
  # --- Brand 本体 ---
  brand = upsert_brand!(
    # この案の起点になった Research の slug（系譜トラッキング・必須）
    research_slug: "weekly_trends_2026_w23",

    slug: "shittori_rakko",
    character_name: "しっとりラッコ",
    series_name: "しっとり労りラッコスタンプ",
    persona_name: "しっとりラッコ",
    concept: "雨の日の体調ゆらぎや低気圧不調に寄り添い、柔らかい敬語でそっとねぎらう海のラッコキャラクター",
    target_audience: "20〜40代 リモートワーカー・在宅勤務者・職場や家族に気づかいを伝えたいビジネス層",
    description: "「大丈夫ですか」「無理しないでくださいね」を重たくならずに届けられる、梅雨・低気圧期の気づかい特化ブランド。業務連絡にも私用にも馴染む丁寧語設計",
    primary_color: "#B8D4C8",

    # 二段定義「○○ではない、○○な△△」で輪郭を絞る
    two_part_definition: "ただかわいい海の生き物ではない、しっとりした敬語で相手の体調をそっと包み込む気づかいの専門家ラッコである。",

    # キャラパーツ 7 部位（持たない部位は空文字で残す＝プロンプトに出ない）
    character_parts: {
      eyes:   "大きめの丸い黒目・下まぶたに細い線、いつも少し心配そうに見える",
      mouth:  "小さなΩ型・困り顔でも愛嬌がある",
      ears:   "小さく丸い耳・頭の上でやや内側に向く",
      body:   "ずんぐりした2頭身の丸い胴体・ふっくらしている",
      limbs:  "短くふっくらした前足・両前足を顔の両脇に添える「包み込みポーズ」が特徴",
      tail:   "扁平で楕円形・体の後ろに少し見える",
      collar: ""
    },

    # フォント仕様
    font_spec: {
      primary: "丸ゴシック",
      color:   "#3D5A6B",
      outline: "白フチ 3px"
    },

    # トーン軸（スコア付き jsonb）
    tone_axes:   { gentle: 0.95, cute: 0.7, neat: 0.45 },

    # ターゲット軸
    target_axes: {
      age:        %w[20s 30s 40s],
      gender:     "unisex",
      occupation: "リモートワーカー・在宅勤務者・気づかい重視のビジネス層"
    },

    # 識別軸（他ブランドと絶対に混同されない核・使わない軸は空文字で残す）
    identity_axes: {
      silhouette:      "2頭身・丸い輪郭・両前足を顔の両脇に添えた「包み込みポーズ」。黒塗りシルエットで見ても『丸い手が顔を包む生き物』と分かる独特の形",
      name_origin:     "『しっとり』= 雨・湿り気の柔らかさ + 丁寧なねぎらい。読み: しっとりらっこ",
      signature:       "両前足で顔の両脇を包む「包み込みポーズ」（全構図で必ず描く・ラッコ固有の識別要素）",
      signature_color: "くすみ水青 #8BB5C8 を主役色として占有（ameagari_usagi の空色系とは彩度・明度で明確に差別化）",
      desire_weakness: "求める: 相手の不安をそっと和らげること / 苦手: 急かすことや強い言い切り表現",
      voice:           "「〜ですね」「〜ですよ」「〜ですか？」で終わる柔らかい敬語形・問いかけを多用し断定を避ける",
      behavior:        "心配するとき両前足を自分の頬に当てて体を少し丸める"
    },

    base_compositions: [
      "正面・両前足で顔を包む（包み込みポーズ）",
      "正面・うっすら微笑み",
      "正面・心配そうな表情",
      "正面・軽くお辞儀",
      "横向き立ち",
      "寝そべり",
      "正面・小さく手を振る",
      "正面・両手をそっと差し出す"
    ]
  )

  attach_communication_themes!(brand, %w[
    appreciation_for_effort
    gratitude
    encouragement
    greeting_morning
    greeting_night
    quick_answer
    need_break
    agreement
  ])

  attach_attribute_values!(brand, {
    tone:        %w[gentle cute neat],
    motif:       %w[animal],
    demographic: %w[age_20s age_30s age_40s business_user unisex],
    setting:     %w[remote_work home office with_friends with_family]
  })

  # --- 初回 Pack（必ず 8 stamps） ---
  create_pack!(
    brand:             brand,
    slug:              "pack_001",
    series_theme:      "雨の日の体調気づかいと短文ねぎらい",
    position:          1,
    layer:             "core_care",
    purchase_unit_size: 8,
    world_view:        "梅雨・低気圧の日でも相手の気持ちをそっと包み込む、柔らかい敬語の気づかいセット",
    usage_scenes:      %w[remote_work home with_friends],
    target_emotions:   %w[安心 共感 労り 気遣い],
    communication_themes: %w[
      appreciation_for_effort
      gratitude
      encouragement
      greeting_morning
      greeting_night
      quick_answer
      need_break
      agreement
    ],
    attributes: {
      tone:    %w[gentle],
      setting: %w[remote_work home]
    },
    stamps: [
      {
        label:                       "おはようございます",
        primary_communication_theme: "greeting_morning",
        communication_themes:        %w[greeting_morning],
        attributes:                  { tone: %w[gentle], setting: %w[remote_work home] },
        situation:                   "雨の朝の業務開始挨拶",
        intent:                      "天気が悪い朝でも温かく1日を始める",
        pose_spec:                   "正面・うっすら微笑み・軽く手を振る",
        props:                       "なし",
        usage_scene:                 "朝のチャット挨拶・業務開始連絡",
        communication_purpose:       "返信負担を増やさず温度を伝える",
        search_keywords:             %w[おはよう 朝 挨拶 業務開始]
      },
      {
        label:                       "お疲れさまでした",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes:        %w[appreciation_for_effort],
        attributes:                  { tone: %w[gentle], setting: %w[office remote_work] },
        situation:                   "業務終了時のねぎらい",
        intent:                      "相手の頑張りをそっと肯定する",
        pose_spec:                   "正面・両前足で顔を包む包み込みポーズ",
        props:                       "なし",
        usage_scene:                 "業務終了 / 退勤時のチャット",
        communication_purpose:       "短文でねぎらいの温度を伝える",
        search_keywords:             %w[おつかれ ねぎらい 退勤 仕事]
      },
      {
        label:                       "大丈夫ですか",
        primary_communication_theme: "agreement",
        communication_themes:        %w[agreement],
        attributes:                  { tone: %w[gentle], setting: %w[home with_friends] },
        situation:                   "低気圧や体調不良を察知したときの確認",
        intent:                      "相手への心配を押しつけがましくなく伝える",
        pose_spec:                   "正面・心配そうな表情・両前足を頬に添える",
        props:                       "なし",
        usage_scene:                 "天候不調・体調確認の一言",
        communication_purpose:       "問いかけで相手に返しやすい余白を作る",
        search_keywords:             %w[大丈夫 心配 体調 確認]
      },
      {
        label:                       "ゆっくり休んでください",
        primary_communication_theme: "need_break",
        communication_themes:        %w[need_break],
        attributes:                  { tone: %w[gentle], setting: %w[home remote_work] },
        situation:                   "疲れている相手や体調を崩した相手への気づかい",
        intent:                      "無理しないよう穏やかに促す",
        pose_spec:                   "正面・体を少し丸めた心配顔",
        props:                       "なし",
        usage_scene:                 "低気圧不調・疲労時の気づかいメッセージ",
        communication_purpose:       "押しつけがましくなく休息を勧める",
        search_keywords:             %w[休んで 体調 労り 無理しないで]
      },
      {
        label:                       "ありがとうございます",
        primary_communication_theme: "gratitude",
        communication_themes:        %w[gratitude],
        attributes:                  { tone: %w[gentle], setting: %w[office home] },
        situation:                   "協力してもらったときや気づかいを受けたとき",
        intent:                      "感謝を柔らかく丁寧に伝える",
        pose_spec:                   "正面・軽くお辞儀",
        props:                       "なし",
        usage_scene:                 "相手の協力・サポートを受けたとき",
        communication_purpose:       "形式的にならない丁寧な感謝表現",
        search_keywords:             %w[ありがとう 感謝 お礼 助かった]
      },
      {
        label:                       "無理しないでくださいね",
        primary_communication_theme: "encouragement",
        communication_themes:        %w[encouragement],
        attributes:                  { tone: %w[gentle], setting: %w[home with_friends with_family] },
        situation:                   "無理をしがちな相手を気づかうとき",
        intent:                      "ペースを守るよう前向きに背中を支える",
        pose_spec:                   "正面・両手をそっと差し出す",
        props:                       "なし",
        usage_scene:                 "忙しい時期・梅雨の体調管理の場面",
        communication_purpose:       "励ましより先に相手を守る言葉を届ける",
        search_keywords:             %w[無理しないで 応援 梅雨 気づかい]
      },
      {
        label:                       "了解です",
        primary_communication_theme: "quick_answer",
        communication_themes:        %w[quick_answer],
        attributes:                  { tone: %w[gentle neat], setting: %w[office remote_work] },
        situation:                   "依頼や連絡をサクッと受け取るとき",
        intent:                      "受領を柔らかく短く伝える",
        pose_spec:                   "正面・うっすら微笑み・軽くうなずき",
        props:                       "なし",
        usage_scene:                 "業務チャットの即レス",
        communication_purpose:       "返信負担を最小化しつつ温度を保つ",
        search_keywords:             %w[了解 返事 OK 確認]
      },
      {
        label:                       "おやすみなさい",
        primary_communication_theme: "greeting_night",
        communication_themes:        %w[greeting_night],
        attributes:                  { tone: %w[gentle], setting: %w[home with_friends with_family] },
        situation:                   "1日の終わりのおやすみ挨拶",
        intent:                      "相手の夜をそっと温かく締めくくる",
        pose_spec:                   "正面・目を細めた微笑み・軽く手を振る",
        props:                       "なし",
        usage_scene:                 "夜の退勤後・就寝前のメッセージ",
        communication_purpose:       "1日の終わりに温かさを添える",
        search_keywords:             %w[おやすみ 夜 挨拶 ゆっくり]
      }
    ]
  )
end
