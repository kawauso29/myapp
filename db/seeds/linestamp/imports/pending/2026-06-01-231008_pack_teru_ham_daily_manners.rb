# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-06-01-231008_pack_teru_ham_daily_manners") do
  brand = Linestamp::Brand.find_by!(slug: "teru_ham")

  create_pack!(
    brand: brand,
    slug: "teru_ham_daily_manners",
    series_theme: "ハムとの丁寧な日常あいさつ",
    position: 2,
    layer: "weekend",
    purchase_unit_size: 8,
    world_view: "小さな礼儀が毎日をやさしく整える、てるハムの暮らし。",
    usage_scenes: %w[home office with_family with_friends],
    target_emotions: %w[安心 礼儀 ぬくもり],
    communication_themes: %w[greeting_morning gratitude agreement greeting_night],
    attributes: {
      tone: %w[gentle cute funny],
      setting: %w[home office with_family]
    },
    stamps: [
      {
        label: "おはようございます",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[greeting_morning],
        attributes: { tone: %w[gentle], setting: %w[home] }
      },
      {
        label: "いってらっしゃい",
        primary_communication_theme: "encouragement",
        communication_themes: %w[encouragement],
        attributes: { tone: %w[gentle], setting: %w[with_family office] }
      },
      {
        label: "ただいま〜",
        primary_communication_theme: "status_busy",
        communication_themes: %w[status_busy],
        attributes: { tone: %w[funny], setting: %w[home] }
      },
      {
        label: "おかえりなさい",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[gentle], setting: %w[home with_family] }
      },
      {
        label: "ありがとう！",
        primary_communication_theme: "gratitude",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[cute], setting: %w[home with_friends] }
      },
      {
        label: "ごめんね",
        primary_communication_theme: "apology",
        communication_themes: %w[apology],
        attributes: { tone: %w[gentle], setting: %w[office] }
      },
      {
        label: "よろしくお願いします",
        primary_communication_theme: "agreement",
        communication_themes: %w[agreement],
        attributes: { tone: %w[gentle], setting: %w[office with_friends] }
      },
      {
        label: "おやすみなさい",
        primary_communication_theme: "greeting_night",
        communication_themes: %w[greeting_night],
        attributes: { tone: %w[gentle], setting: %w[home with_family] }
      }
    ]
  )
end
