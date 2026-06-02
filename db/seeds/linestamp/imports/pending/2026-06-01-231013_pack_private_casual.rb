# frozen_string_literal: true

# teru_ham — Pack 2: プライベート秒レス (private_casual)
# ブランド「秒レスてるてるハム」の 2nd パック。
# pack_001(仕事/在宅ワーク向け秒レス) に続く、プライベート・カジュアル場面特化パック。
# 仕事以外の友人・恋人・家族とのやりとりで 1〜5 文字の秒レスを届ける。

Linestamp::Importer.run(seed_id: "2026-06-01-231013_pack_private_casual") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "private_casual",
    series_theme: "プライベート秒レス",
    position: 2,
    layer: "casual_life",
    purchase_unit_size: 8,
    world_view: "仕事を離れた日常で、1〜5 文字の秒レスで気持ちだけを軽く届ける",
    usage_scenes: %w[home with_friends with_lover with_family],
    target_emotions: %w[親しみ 共感 楽しさ],
    communication_themes: %w[
      greeting_night
      on_the_way
      confirm_meetup
      meal_invitation
      friendly_tease
      need_focus
      status_busy
      celebration
    ],
    attributes: {
      tone: %w[cute gentle funny],
      setting: %w[home with_friends with_lover with_family]
    },
    stamps: [
      {
        label: "おやすみ",
        primary_communication_theme: "greeting_night",
        communication_themes: %w[greeting_night],
        attributes: { tone: %w[gentle cute], setting: %w[home with_family] },
        situation: "就寝前に相手に一言伝えるとき",
        intent: "ふんわりと夜の挨拶を届ける",
        pose_spec: "目を細めて軽く手を振る・眠そうな表情",
        props: "なし",
        usage_scene: "就寝前メッセージ",
        communication_purpose: "返信不要な温かみのあるおやすみ",
        search_keywords: %w[おやすみ 夜 就寝]
      },
      {
        label: "いくよ",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_lover] },
        situation: "待ち合わせ場所に向かうと伝えるとき",
        intent: "今向かっていることを一言で共有",
        pose_spec: "小走り・前傾姿勢",
        props: "なし",
        usage_scene: "待ち合わせ前の移動中",
        communication_purpose: "到着予告を最短で",
        search_keywords: %w[今行く 向かう 待って]
      },
      {
        label: "どこ？",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_lover] },
        situation: "集合場所や相手の居場所を確認するとき",
        intent: "気軽に場所を聞く",
        pose_spec: "首をかしげて周囲を見回す",
        props: "なし",
        usage_scene: "集合場所確認",
        communication_purpose: "問いかけを軽いトーンで",
        search_keywords: %w[どこ 場所 集合]
      },
      {
        label: "たべよ",
        primary_communication_theme: "meal_invitation",
        communication_themes: %w[meal_invitation],
        attributes: { tone: %w[cute gentle], setting: %w[with_friends with_family with_lover] },
        situation: "食事に誘いたいとき",
        intent: "さりげなくご飯を提案する",
        pose_spec: "お腹に手を当てて嬉しそうな表情",
        props: "なし",
        usage_scene: "ランチ・ご飯の誘い",
        communication_purpose: "誘いを圧力なしに",
        search_keywords: %w[ごはん 食事 ランチ]
      },
      {
        label: "うける",
        primary_communication_theme: "friendly_tease",
        communication_themes: %w[friendly_tease],
        attributes: { tone: %w[funny cute], setting: %w[with_friends with_lover] },
        situation: "面白いことを言われてツッコミたいとき",
        intent: "笑いながら相手をいじる",
        pose_spec: "口を開けて笑う・両手を顔の前で振る",
        props: "なし",
        usage_scene: "友人との雑談・ノリツッコミ",
        communication_purpose: "笑いで距離を縮める",
        search_keywords: %w[ウケる 笑い ツッコミ]
      },
      {
        label: "集中中",
        primary_communication_theme: "need_focus",
        communication_themes: %w[need_focus],
        attributes: { tone: %w[funny gentle], setting: %w[home with_friends] },
        situation: "趣味や作業に没頭しているとき",
        intent: "今は邪魔しないでの雰囲気を出す",
        pose_spec: "前のめりで画面を見つめる・目が真剣",
        props: "なし",
        usage_scene: "趣味・勉強・作業中の返信遅延連絡",
        communication_purpose: "角を立てずにそっとしておいてを伝える",
        search_keywords: %w[集中 作業中 邪魔しないで]
      },
      {
        label: "忙し〜",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy],
        attributes: { tone: %w[funny gentle], setting: %w[home with_friends with_family] },
        situation: "今は手が回らないと伝えたいとき",
        intent: "忙しさを愚痴っぽくなく共有",
        pose_spec: "大量のモノに囲まれて汗をかきながら困り顔",
        props: "なし",
        usage_scene: "忙しいアピール・返信遅延の言い訳",
        communication_purpose: "忙しさをキャラで緩和",
        search_keywords: %w[忙しい 手が回らない バタバタ]
      },
      {
        label: "やった！",
        primary_communication_theme: "celebration",
        communication_themes: %w[celebration],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_family with_lover] },
        situation: "嬉しいニュースや達成を共有するとき",
        intent: "喜びを一言で爆発させる",
        pose_spec: "両手を挙げてジャンプ・満面の笑み",
        props: "なし",
        usage_scene: "お祝い・達成報告・嬉しいニュース",
        communication_purpose: "喜びのテンションを秒で届ける",
        search_keywords: %w[やった 達成 お祝い]
      }
    ]
  )
end
