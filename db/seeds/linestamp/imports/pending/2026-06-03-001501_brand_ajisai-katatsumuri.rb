# frozen_string_literal: true

# ブランド「あじさいカタツムリの“ゆっくりでいい”」 — 由来: weekly_trends_2026_w24 brand_idea B
# 急かさず自分のペースを肯定する梅雨モチーフ。横長の渦巻き殻が一目で識別できる。
# 既存ブランドと シルエット(横長渦巻き殻)・シグネチャ(あじさい殻+葉の傘)・色(青紫 #6E7BB5)で被らない。

Linestamp::Importer.run(seed_id: "2026-06-03-001501_brand_ajisai-katatsumuri") do
  brand = upsert_brand!(
    slug: "ajisai_katatsumuri",
    character_name: "でんでん（デンデン）",
    series_name: "ゆっくりでいい",
    persona_name: "急かさない梅雨の相棒",
    concept: "自分のペースを肯定し、急かさない梅雨モチーフ。離席・即レス・同意をやわらかく伝える。",
    target_audience: "20〜40代。在宅/出社問わず“角を立てない離席・即レス”が必要な層。マイペースを大切にしたい人。",
    description: "あじさい色の横長の渦巻き殻を背負ったカタツムリ。眠そうな半目で、語尾を伸ばしてのんびり話す。慌てる相手に殻からそっと顔を出して待つ。梅雨中盤のだるさに寄り添い“ゆっくりでいい”と肯定する。",
    primary_color: "#6E7BB5",
    research_slug: "weekly_trends_2026_w24",
    two_part_definition: "ただ遅いカタツムリではない。“ゆっくりでいい”と肯定してくれる相棒だ。",
    character_parts: {
      eyes: "つぶらで眠そうな半目がちの瞳",
      mouth: "小さな「・」の口。穏やかな表情",
      ears: "耳はなく、2本の触角が役割を兼ねる（先に小さな水玉）",
      body: "やわらかい胴 + 背中にあじさい色の横長の渦巻き殻",
      limbs: "足はなく、波打つ腹足でゆっくり進む",
      tail: "腹足の後端がしっぽ状にすぼまる",
      collar: "2本の触角（先端に雨粒。シグネチャ）"
    },
    font_spec: {
      primary: "やわらか丸ゴシック",
      color: "#6E7BB5",
      outline: "雨粒の白フチ"
    },
    tone_axes: {
      warmth: "高（穏やか）",
      formality: "低〜中（カジュアル寄り）",
      energy: "低（のんびり）"
    },
    target_axes: {
      age: "20〜40代",
      relationship: "友人×職場のゆるい連絡",
      usage: "離席・即レス・同意・労り"
    },
    identity_axes: {
      silhouette: "横長の渦巻き殻を背負った低い輪郭。黒塗りでも“殻つきの横長”と分かる（最重要）",
      signature: "あじさい色の渦巻き殻 ＋ 葉っぱの傘",
      signature_color: "#6E7BB5（あじさいの青紫）",
      voice: "のんびり、語尾を伸ばす、急かさない",
      behavior: "慌てる相手に殻からそっと顔を出して待つ",
      desire_weakness: "マイペースすぎて置いていかれる不安",
      name_origin: "でんでんむし ＋ “ゆっくりでいい”の合言葉"
    },
    base_compositions: [
      "葉っぱの傘の下で半目で休むポーズ",
      "殻からそっと顔を出して待つポーズ",
      "ゆっくり進みながら片手を上げるポーズ"
    ]
  )

  attach_communication_themes!(brand, %w[
    status_busy
    need_break
    quick_answer
    agreement
    on_the_way
    encouragement
    greeting_night
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute neat],
    motif: %w[animal plant],
    demographic: %w[age_20s age_30s age_40s unisex for_female],
    setting: %w[home remote_work with_friends office]
  })

  create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "ゆっくりでいい はじめの渦巻き",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    world_view: "梅雨の雨音の中、あじさい色の殻を背負ったでんでんが“ゆっくりでいい”と肯定する。急かさず、相手のペースを待つやさしい世界。",
    usage_scenes: %w[離席の一言 即レス 同意 だるさへの寄り添い 夜の挨拶],
    target_emotions: %w[安心 共感 労り 落ち着き],
    communication_themes: %w[status_busy need_break quick_answer agreement on_the_way encouragement greeting_night],
    attributes: {
      tone: %w[gentle cute neat],
      motif: %w[animal plant],
      demographic: %w[age_20s age_30s age_40s unisex for_female],
      setting: %w[home remote_work with_friends office]
    },
    stamps: [
      {
        label: "ちょっと休もう",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break encouragement],
        attributes: { tone: %w[gentle], motif: %w[animal], demographic: %w[unisex], setting: %w[home remote_work] },
        situation: "疲れ・だるさを感じたとき",
        intent: "頑張りすぎを止めて休息を促す",
        pose_spec: "葉の傘の下で半目、湯気のカップ",
        props: "葉っぱの傘 + 小さなカップ",
        usage_scene: "在宅勤務・梅雨のだるい日",
        communication_purpose: "休息をやさしく提案",
        search_keywords: %w[休憩 ひと休み ゆっくり でんでん]
      },
      {
        label: "今ちょっと立て込み中",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy quick_answer],
        attributes: { tone: %w[neat gentle], motif: %w[animal], demographic: %w[business_user unisex], setting: %w[office remote_work] },
        situation: "手が離せない・離席する直前",
        intent: "角を立てずに状況を共有する",
        pose_spec: "殻から半分顔を出し、片手で“ちょっと待ってね”",
        props: "渦巻き殻",
        usage_scene: "仕事・家事で取り込み中の連絡",
        communication_purpose: "冷たく見せずに離席・遅延を伝える",
        search_keywords: %w[取り込み中 忙しい 離席 でんでん]
      },
      {
        label: "りょ、ゆっくりでいいよ",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer agreement],
        attributes: { tone: %w[cute gentle], motif: %w[animal], demographic: %w[age_20s unisex], setting: %w[with_friends home] },
        situation: "短く返したいとき",
        intent: "即レスしつつ相手を急かさない",
        pose_spec: "触角をぴこっと立てて軽く返事",
        props: "雨粒",
        usage_scene: "友人とのカジュアルな即レス",
        communication_purpose: "軽い了承で安心を返す",
        search_keywords: %w[りょ 了解 ゆっくり でんでん]
      },
      {
        label: "うんうん、それでいい",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement encouragement],
        attributes: { tone: %w[gentle], motif: %w[animal], demographic: %w[unisex], setting: %w[with_friends office] },
        situation: "相手の提案に同意するとき",
        intent: "肯定して背中を押す",
        pose_spec: "うんうんと頷くしぐさ",
        props: "渦巻き殻",
        usage_scene: "相談ごとへの肯定的な相づち",
        communication_purpose: "受容と肯定を伝える",
        search_keywords: %w[うんうん 同意 そうだね でんでん]
      },
      {
        label: "いま向かってるよ〜",
        primary_communication_theme: "on_the_way",
        communication_themes: %w[on_the_way status_busy],
        attributes: { tone: %w[cute gentle], motif: %w[animal], demographic: %w[unisex], setting: %w[with_friends] },
        situation: "移動中・到着が少し遅れるとき",
        intent: "のんびりでも安心させる進捗共有",
        pose_spec: "葉の傘をさしてゆっくり進む",
        props: "葉っぱの傘",
        usage_scene: "待ち合わせ前の連絡",
        communication_purpose: "到着見込みをやわらかく伝える",
        search_keywords: %w[向かってる 移動中 もうすぐ でんでん]
      },
      {
        label: "あせらなくて大丈夫",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement need_break],
        attributes: { tone: %w[gentle neat], motif: %w[animal plant], demographic: %w[unisex for_female], setting: %w[home remote_work] },
        situation: "相手が焦っている・落ち込んでいるとき",
        intent: "ペースを肯定して安心を返す",
        pose_spec: "あじさいの花を差し出し見上げる",
        props: "あじさいの花",
        usage_scene: "しんどい相手への寄り添い",
        communication_purpose: "焦りをほどき安心を渡す",
        search_keywords: %w[大丈夫 焦らない ゆっくり でんでん あじさい]
      },
      {
        label: "おやすみ、雨の音きいて",
        primary_communication_theme: "greeting_night",
        communication_themes: %w[greeting_night need_break],
        attributes: { tone: %w[gentle neat], motif: %w[animal], demographic: %w[unisex], setting: %w[home] },
        situation: "夜の締めの挨拶",
        intent: "梅雨の夜に落ち着いた眠りを願う",
        pose_spec: "殻に半分入って目を閉じる",
        props: "三日月 + 雨粒",
        usage_scene: "就寝前のチャット",
        communication_purpose: "穏やかな夜の挨拶",
        search_keywords: %w[おやすみ 夜 雨 でんでん]
      },
      {
        label: "マイペースでいこ",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break agreement],
        attributes: { tone: %w[cute gentle], motif: %w[animal], demographic: %w[age_20s age_30s unisex], setting: %w[with_friends remote_work] },
        situation: "気負わず進めたいとき",
        intent: "自分と相手のペースを肯定する",
        pose_spec: "片手を軽く上げて前向きに進む",
        props: "渦巻き殻",
        usage_scene: "ゆるい励まし・自己肯定",
        communication_purpose: "マイペースを肯定する合言葉",
        search_keywords: %w[マイペース ゆっくり 自分らしく でんでん]
      }
    ]
  )
end
