# frozen_string_literal: true

# Brand seed template for Linestamp::Importer DSL
# File: db/seeds/linestamp/imports/pending/{YYYY-MM-DD-HHMMSS}_brand_{slug}.rb
#
# Required: slug, character_name, series_name
# Optional: brand_prompt, base_prompt, two_part_definition, concept,
#           target_audience, persona_name, description, primary_color,
#           background_color_for_gen, character_parts, font_spec, target_axes, tone_axes
#
# Communication themes: array of slug strings (must exist in masters)
# Attributes: hash of { axis_slug => [value_slugs] }

Linestamp::Importer.run(seed_id: "REPLACE_WITH_UNIQUE_ID") do
  brand = upsert_brand!(
    slug: "my_brand",
    character_name: "キャラ名",
    series_name: "シリーズ名",
    persona_name: "ペルソナ名",
    concept: "ブランドコンセプト",
    target_audience: "ターゲット層の説明",
    description: "ブランド説明"
  )

  attach_communication_themes!(brand, %w[gratitude encouragement])
  attach_attribute_values!(brand, {
    tone: %w[gentle cute],
    motif: %w[animal],
    demographic: %w[age_20s for_female],
    setting: %w[home remote_work]
  })
end
