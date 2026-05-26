# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-05-26-224737_brand_ganbarimiru_kaeru") do
  brand = upsert_brand!(
    slug: "ganbarimiru_kaeru",
    character_name: "がんばり見てるカエル",
    series_name: "がんばり見てるカエルスタンプ",
    persona_name: "がんばるくん",
    concept: "相手の努力をそっと見守り、短い言葉でねぎらう小さなカエル。日々頑張る人の傍らにいる存在として、ねぎらいと励ましを自然に届ける。",
    target_audience: "20〜40代のビジネスパーソン・在宅ワーカー。職場の同僚・友人・家族との日常連絡で、相手の頑張りをさりげなく認めたい人。",
    description: "ゆるかわいいカエルが「お疲れさま」「がんばったね」をさまざまな表情で届けるスタンプ。ねぎらい・励ましに特化しつつ、挨拶や簡易回答にも使える汎用性が高い構成。",
    primary_color: "#78C85A",
    background_color_for_gen: "#E8F5E9"
  )

  attach_communication_themes!(brand, %w[
    appreciation_for_effort
    encouragement
    gratitude
    greeting_morning
    greeting_night
    quick_answer
    need_break
    agreement
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute funny],
    motif: %w[animal],
    demographic: %w[age_20s age_30s age_40s unisex business_user],
    setting: %w[office remote_work home with_friends with_family]
  })
end
