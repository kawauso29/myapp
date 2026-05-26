# frozen_string_literal: true

# Research seed template for Linestamp::Importer DSL
# File: db/seeds/linestamp/imports/pending/{YYYY-MM-DD-HHMMSS}_research_{slug}.rb
#
# Required: slug, title
# Optional: body, findings, brand_ideas, line_market_insights,
#           communication_substitute_needs, source_url, keywords, emotions, seasons
#
# Communication themes: array of slug strings (must exist in masters)
# Attributes: hash of { axis_slug => [value_slugs] }

Linestamp::Importer.run(seed_id: "REPLACE_WITH_UNIQUE_ID") do
  upsert_research!(
    slug: "research_topic_name",
    title: "リサーチタイトル",
    body: "調査の概要",
    findings: "主な発見事項",
    brand_ideas: "ブランドアイデア候補",
    line_market_insights: "LINEスタンプ市場の洞察",
    communication_substitute_needs: "代替コミュニケーションニーズ",
    source_url: "https://example.com/source",
    keywords: %w[キーワード1 キーワード2],
    emotions: %w[感情1 感情2],
    seasons: %w[spring summer],
    communication_themes: %w[remote_work_report gratitude],
    attributes: {
      tone: %w[gentle cute],
      demographic: %w[age_20s age_30s],
      setting: %w[remote_work office]
    }
  )
end
