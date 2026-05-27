# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-05-26-224731_brand_ameagari_usagi") do
  brand = upsert_brand!(
    slug: "ameagari_usagi",
    character_name: "雨あがりうさぎ",
    series_name: "雨あがりうさぎの気づかい連絡",
    persona_name: "雨あがりうさぎ",
    concept: "雨の日でもやさしく状況共有し、相手の気持ちを軽くする在宅ワーク向けキャラクター",
    target_audience: "20〜30代の在宅/ハイブリッド勤務ユーザーと、その同僚・友人",
    description: "短文で使いやすい報連相とねぎらい表現を、ふんわり前向きな雰囲気で届けるブランド",
    primary_color: "#8EC5FC",
    background_color_for_gen: "#EAF6FF"
  )

  attach_communication_themes!(brand, %w[
    remote_work_report
    quick_answer
    appreciation_for_effort
    need_break
    greeting_morning
    gratitude
  ])
  attach_attribute_values!(brand, {
    tone: %w[gentle cute neat],
    motif: %w[animal plant],
    demographic: %w[age_20s age_30s business_user unisex],
    setting: %w[remote_work office home with_friends]
  })
end
