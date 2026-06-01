# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-230953_pack_rainy_care") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "rainy_care",
    series_theme: "梅雨どきのひとこと気づかい",
    position: 2,
    layer: "seasonal",
    purchase_unit_size: 8,
    world_view: "雨の日の重たい空気を、てるてるハムの短文でふわっと軽くする",
    usage_scenes: %w[remote_work office home with_friends],
    target_emotions: %w[安心 共感 労り],
    communication_themes: %w[agreement encouragement need_break status_busy quick_answer gratitude apology appreciation_for_effort],
    attributes: {
      tone: %w[cute gentle],
      setting: %w[remote_work office home with_friends]
    },
    stamps: [
      {
        label: "雨だね",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[gentle], setting: %w[with_friends home] },
        search_keywords: %w[雨 共感 天気]
      },
      {
        label: "むりせず",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle], setting: %w[remote_work office] },
        search_keywords: %w[励まし 体調 気づかい]
      },
      {
        label: "ちょい休憩",
        primary_communication_theme: "need_break",
        communication_themes: %w[need_break],
        attributes: { tone: %w[cute gentle], setting: %w[remote_work office] },
        search_keywords: %w[休憩 離席 ひとやすみ]
      },
      {
        label: "立てこんでる",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy],
        attributes: { tone: %w[gentle], setting: %w[office remote_work] },
        search_keywords: %w[忙しい 手が離せない 後で]
      },
      {
        label: "あとで返す",
        primary_communication_theme: "quick_answer",
        communication_themes: %w[quick_answer status_busy],
        attributes: { tone: %w[gentle], setting: %w[remote_work office] },
        search_keywords: %w[返信 後ほど 了解]
      },
      {
        label: "助かった",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[cute gentle], setting: %w[office home] },
        search_keywords: %w[感謝 ありがとう お礼]
      },
      {
        label: "ごめんね",
        primary_communication_theme: "apology",
        communication_themes: %w[apology],
        attributes: { tone: %w[gentle], setting: %w[office with_friends] },
        search_keywords: %w[謝罪 ごめん 遅れた]
      },
      {
        label: "おつかれさま",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[appreciation_for_effort],
        attributes: { tone: %w[gentle], setting: %w[remote_work office] },
        search_keywords: %w[ねぎらい お疲れ 退勤]
      }
    ]
  )
end
