# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-080018_brand_byouresu_teruteru_ham") do
  brand = upsert_brand!(
    research_slug: "weekly_trends_2026_w23",
    slug: "byouresu_teruteru_ham",
    character_name: "秒レスてるてるハム",
    series_name: "秒レスてるてるハムの梅雨連絡",
    persona_name: "秒レスてるてるハム",
    concept: "梅雨どきの気づかいと実務連絡を、1〜5文字中心の短文でやわらかく返すてるてる坊主みたいなハムスター",
    target_audience: "20〜40代のビジネスユーザーと、短文でも冷たく見せたくない私用チャット利用者",
    description: "雨の日のだるさ共有、即レス、移動連絡を、やさしい短文と丸いしぐさで軽く整えるブランド",
    primary_color: "#F3E3A1",
    two_part_definition: "ただ急かすだけの即レス役ではない、梅雨どきの気づかいを1〜5文字でやわらかく返すてるてる坊主みたいなハムスター。",
    character_parts: {
      eyes: "黒目は小さめのまんまる、まぶたは少し低く落ち着いている",
      mouth: "小さなへの字と短い笑みを使い分ける",
      ears: "丸く小さい耳がフードから少しのぞく",
      body: "てるてる坊主の布をかぶった2頭身の丸い体",
      limbs: "短い手足で、手は前にちょこんと出る",
      tail: "背面で布のすそから少しだけ見える丸いしっぽ",
      collar: "首元を結ぶ雨粒柄の短いリボン"
    },
    font_spec: {
      primary: "角丸ゴシック太め",
      color: "#4D4A3E",
      outline: "白フチ 3px"
    },
    tone_axes: { gentle: 0.94, neat: 0.88, cute: 0.72, funny: 0.31 },
    target_axes: {
      age: %w[age_20s age_30s age_40s],
      gender: %w[unisex],
      occupation: %w[business_user flexible_chat_user]
    },
    identity_axes: {
      silhouette: "てるてる坊主のしずく形シルエットに、下からハムスターの丸耳が少し張り出す2頭身",
      name_origin: "『秒レス』= すぐ返せる短文運用、『てるてる』= 梅雨どきの気分を少し晴らす役割",
      signature: "首元の雨粒柄リボンを毎カット必ず見せる",
      signature_color: "やわらかい晴れ色イエロー #F3E3A1 を占有する",
      desire_weakness: "求める: 相手の返信負担を減らすこと / 苦手: 長文で空気が重くなること",
      voice: "1〜5文字中心でも素っ気なく切らず、やわらかい余白を残す",
      behavior: "返事をするとき小さく前のめりになって布のすそを揺らす"
    },
    base_compositions: [
      "正面・無表情",
      "正面・小さく会釈",
      "正面・片手あげ",
      "正面・両手前",
      "正面・しょんぼり",
      "正面・小走り",
      "斜め前・振り向き",
      "座り・布のすそを広げる",
      "正面・片手でOK",
      "正面・雨粒を見上げる",
      "正面・ふわっと笑顔",
      "横向き・急ぎ足"
    ]
  )

  attach_communication_themes!(brand, %w[
    quick_answer
    appreciation_for_effort
    need_break
    status_busy
    greeting_morning
    on_the_way
    confirm_meetup
    urgent_contact
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle neat cute],
    motif: %w[animal tool],
    demographic: %w[age_20s age_30s age_40s business_user unisex],
    setting: %w[office remote_work home with_friends with_customer]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "梅雨どきの秒レス気づかい",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "雨の日の不調共有と移動連絡を、短文でもやさしく整える",
    usage_scenes: %w[office remote_work home with_friends],
    target_emotions: %w[安心 気遣い 段取り 省エネ],
    communication_themes: %w[
      quick_answer
      appreciation_for_effort
      need_break
      status_busy
      greeting_morning
      on_the_way
      confirm_meetup
      urgent_contact
    ],
    attributes: {
      tone: %w[gentle neat],
      setting: %w[office remote_work home with_friends]
    },
    stamps: [
      {
        label: "おはです",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning quick_answer],
        attributes: { tone: %w[gentle neat], setting: %w[office remote_work] },
        situation: "雨の朝に仕事や連絡を始めるとき",
        intent: "短くやわらかく朝の存在を伝える",
        pose_spec: "正面・小さく会釈",
        props: "なし",
        usage_scene: "朝の業務開始・家族連絡",
        communication_purpose: "即レスでも冷たく見せず挨拶する",
        search_keywords: %w[おはよう 朝 挨拶]
      },
      {
        label: "りょです",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer],
        attributes: { tone: %w[neat], setting: %w[office remote_work] },
        situation: "依頼や共有を受けてすぐ返したいとき",
        intent: "短文で受領を明確にする",
        pose_spec: "正面・片手でOK",
        props: "なし",
        usage_scene: "業務チャットの即返答",
        communication_purpose: "返信負担を下げつつ意思表示する",
        search_keywords: %w[了解 返事 即レス]
      },
      {
        label: "おつです",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        situation: "相手の作業終わりや区切りに声をかけるとき",
        intent: "ねぎらいを軽やかに返す",
        pose_spec: "正面・ふわっと笑顔",
        props: "なし",
        usage_scene: "終業前後のねぎらい",
        communication_purpose: "短文で労りを届ける",
        search_keywords: %w[おつかれ ねぎらい 退勤]
      },
      {
        label: "少し休む",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break status_busy],
        attributes: { tone: %w[gentle neat], setting: %w[remote_work home] },
        situation: "低気圧や疲れで少し離席したいとき",
        intent: "休憩を角なく共有する",
        pose_spec: "座り・布のすそを広げる",
        props: "湯気の出るマグ",
        usage_scene: "離席・中抜け連絡",
        communication_purpose: "体調気づかい文脈で休憩を伝える",
        search_keywords: %w[休憩 離席 体調]
      },
      {
        label: "立てこみ中",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy quick_answer],
        attributes: { tone: %w[neat], setting: %w[office remote_work] },
        situation: "返信はできるが手が離せないとき",
        intent: "忙しさを簡潔に共有する",
        pose_spec: "正面・両手前",
        props: "小さな雨雲アイコン",
        usage_scene: "会議前後の状況共有",
        communication_purpose: "未返信の印象を避ける",
        search_keywords: %w[忙しい 立て込み 手が離せない]
      },
      {
        label: "向かってます",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way confirm_meetup],
        attributes: { tone: %w[neat], setting: %w[office with_friends] },
        situation: "待ち合わせ先へ移動を始めたとき",
        intent: "出発済みを安心感付きで伝える",
        pose_spec: "横向き・急ぎ足",
        props: "小さな傘",
        usage_scene: "訪問先・待ち合わせ連絡",
        communication_purpose: "移動状況を一目で伝える",
        search_keywords: %w[向かう 移動 到着前]
      },
      {
        label: "ついたよ",
        primary_communication_theme: "confirm_meetup",
        communication_themes: %w[confirm_meetup on_the_way],
        attributes: { tone: %w[gentle neat], setting: %w[office with_friends with_customer] },
        situation: "先に現地へ着いたとき",
        intent: "到着と待機をやわらかく伝える",
        pose_spec: "斜め前・振り向き",
        props: "しずく形の案内看板",
        usage_scene: "待ち合わせ場所での到着報告",
        communication_purpose: "相手の迷いを減らす",
        search_keywords: %w[到着 待ち合わせ 現地]
      },
      {
        label: "急ぎです",
        primary_communication_theme: "urgent_contact",
        communication_themes: %w[urgent_contact status_busy],
        attributes: { tone: %w[neat], setting: %w[office with_customer] },
        situation: "至急確認や折り返しをお願いしたいとき",
        intent: "緊急性を保ちつつ圧を下げる",
        pose_spec: "正面・小走り",
        props: "小さなベル",
        usage_scene: "急ぎ確認・至急連絡",
        communication_purpose: "きつく見せず緊急連絡する",
        search_keywords: %w[至急 急ぎ 確認]
      }
    ]
  )
end
