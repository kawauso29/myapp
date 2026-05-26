# frozen_string_literal: true

# Pack seed template for Linestamp::Importer DSL
# File: db/seeds/linestamp/imports/pending/{YYYY-MM-DD-HHMMSS}_pack_{slug}.rb
#
# Required: brand (slug reference), slug, series_theme, position, stamps array
# Optional: layer, world_view, usage_scenes, target_emotions, purchase_unit_size,
#           sheet_prompt, excluded_elements
#
# Each stamp requires: label, primary_communication_theme (slug)
# Each stamp optional: prompt, situation, intent, communication_themes, attributes

Linestamp::Importer.run(seed_id: "REPLACE_WITH_UNIQUE_ID") do
  brand = Linestamp::Brand.find_by!(slug: "my_brand")

  pack = create_pack!(
    brand: brand,
    slug: "pack_001",
    series_theme: "在宅ワークの日常",
    position: 1,
    layer: "core_work",
    purchase_unit_size: 8,
    communication_themes: %w[remote_work_report gratitude],
    attributes: {
      tone: %w[gentle],
      setting: %w[remote_work home]
    },
    stamps: [
      {
        label: "おはよう",
        primary_communication_theme: "greeting_morning",
        communication_themes: %w[remote_work_report],
        attributes: { tone: %w[gentle], setting: %w[remote_work] }
      },
      {
        label: "お疲れさま",
        primary_communication_theme: "appreciation_for_effort",
        communication_themes: %w[gratitude],
        attributes: { tone: %w[gentle], setting: %w[remote_work] }
      }
      # ... 8枚まで
    ]
  )
end
