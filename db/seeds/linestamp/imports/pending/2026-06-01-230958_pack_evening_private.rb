# frozen_string_literal: true

# 秒レスてるてるハム — 夜とプライベートの秒レス (pack_002)
# ブランド: teru_ham
# テーマ: 業務を終えた夜や週末のプライベート場面で、1〜5文字の秒レスでやり取りをスムーズにする
# pack_001(梅雨の秒レス気づかい)と重複しないコミュニケーションテーマで構成

Linestamp::Importer.run(seed_id: "2026-06-01-230958_pack_evening_private") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "evening_private",
    series_theme: "夜とプライベートの秒レス",
    position: 2,
    layer: "core_private",
    purchase_unit_size: 8,
    world_view: "業務を終えた夜や週末に、1〜5文字の秒レスでプライベートをスムーズに進める",
    usage_scenes: %w[home with_friends with_lover with_family],
    target_emotions: %w[安心 親密 楽しさ],
    communication_themes: %w[
      greeting_night remote_work_report on_the_way
      need_focus celebration meal_invitation confirm_meetup friendly_tease
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
        attributes: { tone: %w[cute gentle], setting: %w[home with_family] },
        situation: "寝る前の挨拶を送りたいとき",
        intent: "やわらかく1日を締めくくる",
        pose_spec: "正面・うっすら笑顔・軽く目を閉じかける",
        props: "なし",
        usage_scene: "就寝前の一言",
        communication_purpose: "短文で温かく夜を締める",
        search_keywords: %w[おやすみ 夜 就寝]
      },
      {
        label: "報告ね",
        primary_communication_theme: "remote_work_report",
        communication_themes: %w[remote_work_report],
        attributes: { tone: %w[cute gentle], setting: %w[home with_friends] },
        situation: "近況や進捗を手軽に伝えたいとき",
        intent: "最小文字数で状況を共有する",
        pose_spec: "サムズアップ",
        props: "なし",
        usage_scene: "友人・家族へのゆるい進捗報告",
        communication_purpose: "報告の敷居を下げる",
        search_keywords: %w[報告 連絡 進捗]
      },
      {
        label: "今行く！",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_lover] },
        situation: "待ち合わせや合流のとき",
        intent: "すぐ向かっていることを即伝える",
        pose_spec: "横向き立ち・走る仕草",
        props: "なし",
        usage_scene: "合流直前の「今向かってます」",
        communication_purpose: "移動中でも一言で状況を通知",
        search_keywords: %w[今行く 向かってます 移動中]
      },
      {
        label: "集中中",
        primary_communication_theme: "need_focus",
        communication_themes: %w[need_focus],
        attributes: { tone: %w[cute gentle], setting: %w[home with_friends] },
        situation: "邪魔してほしくないことを伝えたいとき",
        intent: "集中していることを角を立てず知らせる",
        pose_spec: "正面・真顔・口を一文字に結ぶ",
        props: "なし",
        usage_scene: "深夜の作業中・趣味の没頭中",
        communication_purpose: "マナモードで状態を共有",
        search_keywords: %w[集中 作業中 邪魔しないで]
      },
      {
        label: "おめでとう！",
        primary_communication_theme: "celebration",
        communication_themes: %w[celebration],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_family with_lover] },
        situation: "誕生日・記念日・合格などのお祝いをしたいとき",
        intent: "パッと明るいお祝いを届ける",
        pose_spec: "両手で小さくガッツポーズ・笑顔",
        props: "なし",
        usage_scene: "記念日・誕生日メッセージ",
        communication_purpose: "短くても気持ちが伝わるお祝い",
        search_keywords: %w[おめでとう お祝い 誕生日]
      },
      {
        label: "ご飯行こ",
        primary_communication_theme: "meal_invitation",
        communication_themes: %w[meal_invitation],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_lover] },
        situation: "食事に誘いたいとき",
        intent: "気軽に食事の誘いを出す",
        pose_spec: "正面・うっすら笑顔・少し身を乗り出す仕草",
        props: "なし",
        usage_scene: "友人・恋人への食事の誘い",
        communication_purpose: "誘いのハードルを下げる",
        search_keywords: %w[ご飯 食事 誘い]
      },
      {
        label: "場所どこ？",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup],
        attributes: { tone: %w[cute gentle], setting: %w[with_friends with_lover] },
        situation: "待ち合わせ場所や時間を確認したいとき",
        intent: "ズバッと確認して迷子を防ぐ",
        pose_spec: "正面・首を少し傾ける",
        props: "なし",
        usage_scene: "待ち合わせ前の場所・時間確認",
        communication_purpose: "確認を一言で完結させる",
        search_keywords: %w[場所 待ち合わせ どこ]
      },
      {
        label: "それっぽい",
        primary_communication_theme: "friendly_tease",
        communication_themes: %w[friendly_tease],
        attributes: { tone: %w[cute funny], setting: %w[with_friends with_lover] },
        situation: "仲良し相手を軽くいじりたいとき",
        intent: "遊び心のあるツッコミを手軽に入れる",
        pose_spec: "頬杖・にやり顔",
        props: "なし",
        usage_scene: "親しい仲間との軽口・いじり",
        communication_purpose: "距離を縮める軽いユーモア",
        search_keywords: %w[いじり ツッコミ 笑い]
      }
    ]
  )
end
