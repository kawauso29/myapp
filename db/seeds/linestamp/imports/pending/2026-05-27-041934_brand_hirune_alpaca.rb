# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-05-27-041934_brand_hirune_alpaca") do
  brand = upsert_brand!(
    slug: "hirune_alpaca",
    character_name: "ひるねアルパカ",
    series_name: "ひるねアルパカのやさしい報連相",
    persona_name: "ひるねアルパカ",
    concept: "おっとりした表情で在宅ワークの連絡をやわらかく伝え、相手の気持ちをほどくアルパカキャラクター",
    target_audience: "20〜30代の在宅/ハイブリッド勤務ユーザー、チャットで短く丁寧に連絡したいビジネス層",
    description: "「今対応中」「少し休憩」「ありがとう」を角が立たない言い回しで届ける、日常業務向けの気づかいブランド",
    primary_color: "#D9B8A8",
    background_color_for_gen: "#FFF6ED"
  )

  attach_communication_themes!(brand, %w[
    remote_work_report
    quick_answer
    appreciation_for_effort
    need_break
    greeting_morning
    greeting_night
    gratitude
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute neat],
    motif: %w[animal],
    demographic: %w[age_20s age_30s business_user unisex],
    setting: %w[remote_work home office]
  })
end
