# frozen_string_literal: true

# 秒レスてるてるハム — 第2弾「夜と雑談の秒レス」
# 対象ブランド: teru_ham
# Pack_001 が朝〜昼の業務シーンをカバーしたため、
# 本パックは夜帰宅後・週末の気軽なつながりシーンを補完する。
# 8テーマはすべて Pack_001 未使用のマスタ slug を使用。

Linestamp::Importer.run(seed_id: "2026-06-01-231023_pack_night_casual") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "night_casual",
    series_theme: "夜と雑談の秒レス",
    position: 2,
    layer: "weekend",
    purchase_unit_size: 8,
    world_view: "夜の帰宅後や週末の雑談でも、てるてるハムの1〜5文字が温度だけをやわらかく届ける",
    usage_scenes: %w[home with_friends with_lover],
    target_emotions: %w[安心 楽しさ 親しみ],
    communication_themes: %w[
      greeting_night
      remote_work_report
      on_the_way
      confirm_meetup
      need_focus
      status_busy
      celebration
      friendly_tease
    ],
    attributes: {
      tone: %w[cute gentle funny],
      setting: %w[home with_friends with_lover]
    },
    stamps: [
      {
        label: "おやすみ",
        primary_communication_theme: "greeting_night",
        communication_themes: %w[greeting_night],
        attributes: { tone: %w[cute gentle], setting: %w[home] },
        situation: "就寝前の一言挨拶",
        intent: "一日の締めをやわらかく伝える",
        pose_spec: "正面・目をとろっと閉じかけ・小さく手を振る",
        props: "なし",
        usage_scene: "就寝前のLINE",
        communication_purpose: "おやすみをかわいく返せる即レス",
        search_keywords: %w[おやすみ 夜 就寝]
      },
      {
        label: "完了！",
        primary_communication_theme: "remote_work_report",
        communication_themes: %w[remote_work_report],
        attributes: { tone: %w[cute gentle], setting: %w[home] },
        situation: "夜の業務完了や作業終了報告",
        intent: "短く確実に終わりを伝える",
        pose_spec: "サムズアップ・少し誇らしげな表情",
        props: "なし",
        usage_scene: "在宅業務の終了報告",
        communication_purpose: "報告負担ゼロで完了を伝える",
        search_keywords: %w[完了 終わった 報告]
      },
      {
        label: "いま行く",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way],
        attributes: { tone: %w[cute funny], setting: %w[with_friends] },
        situation: "待ち合わせ場所に向かうとき",
        intent: "移動中であることを即伝える",
        pose_spec: "小走り気味の横向き・てるてる形でぴょこぴょこ移動",
        props: "なし",
        usage_scene: "集合場所への移動中",
        communication_purpose: "返信を最速で済ませて移動に集中",
        search_keywords: %w[今行く 移動中 向かってる]
      },
      {
        label: "何時？",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup],
        attributes: { tone: %w[cute funny], setting: %w[with_friends] },
        situation: "待ち合わせの時刻確認",
        intent: "時間をさらっと聞き返す",
        pose_spec: "首を少し傾け疑問顔",
        props: "なし",
        usage_scene: "集合時間が不明・再確認したいとき",
        communication_purpose: "聞き返す手間を1文字で済ませる",
        search_keywords: %w[待ち合わせ 時間確認 何時]
      },
      {
        label: "集中中",
        primary_communication_theme: "need_focus",
        communication_themes: %w[need_focus],
        attributes: { tone: %w[gentle cute], setting: %w[home] },
        situation: "作業に集中していて返信が遅れるとき",
        intent: "邪魔しないでを角を立てず伝える",
        pose_spec: "目を細め前のめりで何かに集中している後ろ姿気味",
        props: "なし",
        usage_scene: "副業・勉強・作業集中タイム",
        communication_purpose: "集中を示しつつ拒絶感ゼロ",
        search_keywords: %w[集中 作業中 邪魔しないで]
      },
      {
        label: "いそがし",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy],
        attributes: { tone: %w[funny cute], setting: %w[home with_friends] },
        situation: "ちょっと手が離せない状況",
        intent: "忙しさをかわいく主張する",
        pose_spec: "両手でばたばたしている慌て顔",
        props: "なし",
        usage_scene: "家事・育児・作業で手が塞がっているとき",
        communication_purpose: "忙しいを笑顔で伝えてハードルを下げる",
        search_keywords: %w[忙しい 後で 待って]
      },
      {
        label: "おめでと",
        primary_communication_theme: "celebration",
        communication_themes: %w[celebration],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_lover] },
        situation: "誕生日・昇進・進学などのお祝い",
        intent: "お祝いを即明るく返す",
        pose_spec: "両手を挙げてぴょんとジャンプ・満面の笑み",
        props: "なし",
        usage_scene: "誕生日・合格・昇進など",
        communication_purpose: "文章を考えず喜びだけ届ける",
        search_keywords: %w[おめでとう 祝い 嬉しい]
      },
      {
        label: "えーマジ",
        primary_communication_theme: "friendly_tease",
        communication_themes: %w[friendly_tease],
        attributes: { tone: %w[funny cute], setting: %w[with_friends with_lover] },
        situation: "驚きと軽い突っ込みを同時に返すとき",
        intent: "相手をいじりながら盛り上げる",
        pose_spec: "目を丸くして口を開けた驚き顔・ほっぺが少し膨らむ",
        props: "なし",
        usage_scene: "友達や恋人との雑談・ボケへの返し",
        communication_purpose: "ウケ狙いの返しをワンタップで",
        search_keywords: %w[まじ 驚き いじり]
      }
    ]
  )
end
