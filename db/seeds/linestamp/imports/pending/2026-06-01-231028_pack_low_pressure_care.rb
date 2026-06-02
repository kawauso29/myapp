# frozen_string_literal: true

# 秒レスてるてるハム 追加 Pack
# テーマ: 低気圧で重たい日でも、短くやわらかく気づかいを返せる梅雨向けシリーズ。

Linestamp::Importer.run(seed_id: "2026-06-01-231028_pack_low_pressure_care") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "low_pressure_care",
    series_theme: "低気圧いたわり秒レス",
    position: 2,
    layer: "seasonal",
    purchase_unit_size: 8,
    world_view: "雨音が続く日でも、てるてる結びのハムが短くやさしく体調と気分を気づかう",
    usage_scenes: %w[remote_work office home with_friends],
    target_emotions: %w[安心 共感 労り],
    communication_themes: %w[
      greeting_morning
      quick_answer
      agreement
      gratitude
      apology
      need_break
      appreciation_for_effort
      encouragement
    ],
    attributes: {
      tone: %w[cute gentle],
      setting: %w[remote_work office home with_friends]
    },
    stamps: [
      {
        label: "雨だね",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning agreement],
        attributes: { tone: %w[gentle], setting: %w[remote_work home] },
        situation: "雨の朝に相手の気分も気づかいたいとき",
        intent: "天気の重さを共有しながらやわらかく挨拶する",
        pose_spec: "窓の外の雨を見ながら小さく手を振る",
        props: "小さな雨粒",
        usage_scene: "梅雨の朝の業務開始・雑談",
        communication_purpose: "会話の入り口をやさしく作る",
        search_keywords: %w[雨 朝 おはよう]
      },
      {
        label: "むりせず",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement need_break],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "相手がしんどそう・忙しそうに見えるとき",
        intent: "頑張りを否定せずに休んでいい空気を出す",
        pose_spec: "胸の前で手を合わせて見上げる",
        props: "なし",
        usage_scene: "体調を気づかう返信",
        communication_purpose: "無理をさせない一言を添える",
        search_keywords: %w[無理しない いたわり 体調]
      },
      {
        label: "あとで!",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer apology],
        attributes: { tone: %w[cute gentle], setting: %w[office remote_work] },
        situation: "すぐ返せないが受け取ったことは伝えたいとき",
        intent: "返信待ちの不安を減らす",
        pose_spec: "片手を上げて急ぎ足ポーズ",
        props: "しずく模様のメモ",
        usage_scene: "会議前後や立て込んだ時間帯",
        communication_purpose: "秒レスで受領だけ先に返す",
        search_keywords: %w[あとで 後ほど 返信]
      },
      {
        label: "やすも",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break encouragement],
        attributes: { tone: %w[gentle], setting: %w[remote_work home] },
        situation: "自分も相手も少し休んだほうがよさそうなとき",
        intent: "休憩を言い出しやすくする",
        pose_spec: "マグカップを抱えて座り込む",
        props: "湯気の立つマグカップ",
        usage_scene: "午後のひと息・離席連絡",
        communication_purpose: "休憩提案を角なく伝える",
        search_keywords: %w[休もう 休憩 離席]
      },
      {
        label: "わかる",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement encouragement],
        attributes: { tone: %w[gentle], setting: %w[home with_friends] },
        situation: "だるさや眠さの話に共感したいとき",
        intent: "説明を求めず気持ちに寄り添う",
        pose_spec: "こくこく頷く正面ポーズ",
        props: "なし",
        usage_scene: "雑談・不調共有への返答",
        communication_purpose: "共感を短く確実に伝える",
        search_keywords: %w[わかる 共感 だるい]
      },
      {
        label: "ありがと",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude appreciation_for_effort],
        attributes: { tone: %w[cute gentle], setting: %w[office home] },
        situation: "フォローや気づかいを受けたとき",
        intent: "重たくしすぎず感謝を返す",
        pose_spec: "ぺこりとおじぎしながら微笑む",
        props: "小さなハート型のしずく",
        usage_scene: "手助けしてもらった直後",
        communication_purpose: "気づかいへのお礼を即返しする",
        search_keywords: %w[ありがとう 感謝 助かる]
      },
      {
        label: "ごめんね",
        primary_communication_theme: "apology",
        communication_themes: %w[apology quick_answer],
        attributes: { tone: %w[gentle], setting: %w[office home] },
        situation: "反応が遅れた・約束をずらしたいとき",
        intent: "低姿勢を保ちつつやわらかく詫びる",
        pose_spec: "白リボンをぎゅっと持ってしょんぼりする",
        props: "なし",
        usage_scene: "返信遅れや軽い予定変更",
        communication_purpose: "謝罪の心理的ハードルを下げる",
        search_keywords: %w[ごめん 謝罪 遅れ]
      },
      {
        label: "おつかれ",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort encouragement],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "雨の日の終業時や一区切りで声をかけたいとき",
        intent: "今日の頑張りをやさしく回収する",
        pose_spec: "てるてる結びを揺らしながら微笑んで手を振る",
        props: "なし",
        usage_scene: "終業前後・タスク完了時",
        communication_purpose: "短文でねぎらいと安心感を渡す",
        search_keywords: %w[おつかれ ねぎらい 退勤]
      }
    ]
  )
end
