# frozen_string_literal: true

Linestamp::Importer.run(seed_id: "2026-05-26-224725_brand_kimochi_kaeru") do
  brand = upsert_brand!(
    slug: "kimochi_kaeru",
    character_name: "きもちわかるカエル",
    series_name: "きもちわかるカエルスタンプ",
    persona_name: "きもちわかるカエル",
    concept: "疲れた気持ちや忙しさを「わかるよ」とそっと包み込む、共感力MAXのカエルキャラクター。大変な日もさりげない一言で乗り越えられる",
    target_audience: "20〜40代 仕事・家事・育児で忙しい男女。社内連絡・家族・友人グループで日常的にスタンプを使う人",
    description: "「大変だったね」「ありがとう」「ここにいるよ」をさらっと伝えられる気づかい系カエルキャラ。オフィス・在宅・プライベートの3シーンで使い回せる万能設計",
    primary_color: "#6DBE85"
  )

  attach_communication_themes!(brand, %w[
    appreciation_for_effort
    gratitude
    encouragement
    agreement
    apology
    quick_answer
    need_break
    greeting_morning
    greeting_night
    status_busy
  ])

  attach_attribute_values!(brand, {
    tone: %w[gentle cute funny],
    motif: %w[animal],
    demographic: %w[age_20s age_30s age_40s unisex business_user],
    setting: %w[office remote_work home with_friends boss_subordinate]
  })
end
