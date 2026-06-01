# frozen_string_literal: true

# 移動中ペンギン便 (penguin_bin)
# Research: weekly_trends_2026_w23 (梅雨本番・低気圧ケアと短文気づかい需要) idea C 由来。
# コンセプト: 遅延・到着・待ち合わせ確認を敬語短文で即共有できる、移動連絡特化ペンギン。

Linestamp::Importer.run(seed_id: "2026-06-01-224741_brand_penguin_bin") do
  brand = upsert_brand!(
    slug: "penguin_bin",
    research_slug: "weekly_trends_2026_w23",
    character_name: "移動中ペンギン便",
    series_name: "移動中ペンギン便の実務連絡",
    persona_name: "移動中ペンギン便",
    concept: "梅雨の遅延や天候乱れがある日でも、到着・遅延・合流確認を短文敬語で素早く共有する連絡特化キャラクター",
    target_audience: "20〜40代の通勤・外出が多いビジネスユーザーと、待ち合わせ調整が多い友人グループ",
    description: "移動ステータスの報連相を、角の立たない短文敬語で即共有できるペンギン便ブランド",
    primary_color: "#4D7EA8",
    two_part_definition: "移動中ペンギン便はただ急いでいる連絡役ではなく、遅延や到着を要点先出しの敬語短文で誤解なく届ける移動連絡専用メッセンジャーである。",
    character_parts: {
      eyes: "小さめの黒目で前方を確認する視線",
      mouth: "短いくちばしで語尾はやわらかい",
      ears: "",
      body: "しずく型の2.5頭身で前傾姿勢",
      limbs: "短い翼と足で素早く小走りする",
      tail: "小さな三角尾羽",
      collar: "オレンジ色の配達タグ付きストラップ"
    },
    font_spec: {
      primary: "角丸ゴシック",
      color: "#1F3A52",
      outline: "white_thick_3px"
    },
    tone_axes: { neat: 0.85, gentle: 0.7, cute: 0.45 },
    target_axes: {
      age: %w[age_20s age_30s age_40s],
      gender: %w[unisex],
      occupation: %w[business_user commuter]
    },
    identity_axes: {
      signature: "胸のオレンジ配達タグを全構図で必ず描く",
      voice: "要点先出しの敬語短文で、断定しすぎず時刻を添える",
      behavior: "移動方向を翼で指し示してから一礼する"
    },
    base_compositions: [
      "正面・軽く会釈",
      "前傾で小走り",
      "片翼で進行方向を指差し",
      "駅看板を見上げる",
      "スマホ確認",
      "足踏みで待機",
      "到着して敬礼",
      "雨粒をよけつつ移動",
      "両翼でOKサイン",
      "深くお辞儀",
      "振り返り確認",
      "メモを差し出す"
    ]
  )

  attach_communication_themes!(brand, %w[
    on_the_way
    confirm_meetup
    urgent_contact
    quick_answer
    status_busy
    apology
    gratitude
    appreciation_for_effort
  ])

  attach_attribute_values!(brand, {
    tone: %w[neat gentle],
    motif: %w[animal],
    demographic: %w[age_20s age_30s age_40s business_user unisex],
    setting: %w[office with_friends with_customer]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "梅雨どき移動連絡の即共有",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "雨と遅延が起きやすい日でも、待つ側の不安を減らす移動報連相",
    usage_scenes: %w[office with_friends with_customer],
    target_emotions: %w[安心 納得 配慮],
    communication_themes: %w[on_the_way confirm_meetup urgent_contact quick_answer status_busy apology gratitude appreciation_for_effort],
    attributes: {
      tone: %w[neat gentle],
      setting: %w[office with_friends with_customer]
    },
    stamps: [
      {
        label: "今向かってます",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way],
        attributes: { tone: %w[neat], setting: %w[office] },
        situation: "移動開始後すぐに状況共有したいとき",
        intent: "先に安心感を渡す",
        pose_spec: "前傾で小走り・片翼で進行方向を指差し",
        props: "スマホ",
        usage_scene: "訪問先への移動中",
        communication_purpose: "到着前の不安を減らす",
        search_keywords: %w[移動中 向かってる 連絡]
      },
      {
        label: "5分遅れます",
        primary_communication_theme: "apology",
        communication_themes: %w[apology urgent_contact],
        attributes: { tone: %w[neat gentle], setting: %w[office with_customer] },
        situation: "電車遅延などで到着が遅れるとき",
        intent: "遅延を早めに詫びて共有する",
        pose_spec: "駅看板を見上げて深くお辞儀",
        props: "駅の時刻表示",
        usage_scene: "商談や打ち合わせ前",
        communication_purpose: "相手の予定調整をしやすくする",
        search_keywords: %w[遅刻 遅延 すみません]
      },
      {
        label: "到着しました",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup],
        attributes: { tone: %w[neat], setting: %w[office with_friends] },
        situation: "待ち合わせ場所に着いたとき",
        intent: "合流開始を明確に伝える",
        pose_spec: "到着して敬礼",
        props: "なし",
        usage_scene: "駅前・受付前での合流",
        communication_purpose: "行き違いを防ぐ",
        search_keywords: %w[到着 合流 待ち合わせ]
      },
      {
        label: "先に入っててください",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer on_the_way],
        attributes: { tone: %w[gentle neat], setting: %w[with_customer with_friends] },
        situation: "自分が少し遅れそうで先行入室をお願いするとき",
        intent: "相手の待機負担を減らす",
        pose_spec: "片翼でOKサイン・軽く会釈",
        props: "入館パス",
        usage_scene: "会議室や店舗の前",
        communication_purpose: "行動指示を短文で伝える",
        search_keywords: %w[先入室 お先に お願い]
      },
      {
        label: "遅延発生です",
        primary_communication_theme: "urgent_contact",
        communication_themes: %w[urgent_contact status_busy],
        attributes: { tone: %w[neat], setting: %w[office with_customer] },
        situation: "交通障害で予定変更が必要になったとき",
        intent: "緊急共有を最短で行う",
        pose_spec: "雨粒をよけつつスマホ確認",
        props: "運行情報画面",
        usage_scene: "移動中のチーム連絡",
        communication_purpose: "意思決定を早める",
        search_keywords: %w[緊急 遅延 連絡]
      },
      {
        label: "この場所で合ってますか？",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup],
        attributes: { tone: %w[gentle neat], setting: %w[with_friends with_customer] },
        situation: "似た場所が多く最終確認したいとき",
        intent: "ミス合流を防ぐ",
        pose_spec: "地図メモを差し出して首をかしげる",
        props: "地図メモ",
        usage_scene: "大型駅・商業施設での待ち合わせ",
        communication_purpose: "認識ズレを事前に解消する",
        search_keywords: %w[場所確認 合ってる 待ち合わせ]
      },
      {
        label: "乗換え混雑中です",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy on_the_way],
        attributes: { tone: %w[neat], setting: %w[office] },
        situation: "混雑で即返信しづらい状態を伝えるとき",
        intent: "返信遅れの理由を先に共有する",
        pose_spec: "人波を避けて足踏み待機",
        props: "通勤バッグ",
        usage_scene: "通勤時間帯の連絡",
        communication_purpose: "既読スルー誤解を防ぐ",
        search_keywords: %w[混雑 取り込み中 乗換]
      },
      {
        label: "ご調整ありがとうございます",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort gratitude],
        attributes: { tone: %w[gentle neat], setting: %w[with_customer office] },
        situation: "時間変更に対応してもらった後",
        intent: "配慮への感謝を丁寧に返す",
        pose_spec: "正面・深くお辞儀",
        props: "なし",
        usage_scene: "再調整後のフォロー",
        communication_purpose: "関係を円滑に保つ",
        search_keywords: %w[調整感謝 お礼 ありがとう]
      }
    ]
  )
end
