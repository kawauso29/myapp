module Linestamp
  class BrandSourcesSyncer
    BRAND_SOURCES_DIR = Rails.root.join("brand_sources")

    def sync_all
      return unless BRAND_SOURCES_DIR.exist?

      Dir.glob(BRAND_SOURCES_DIR.join("*/meta.yml")).each do |meta_path|
        sync_brand(meta_path)
      end
    end

    def sync_brand(meta_path)
      meta = YAML.safe_load_file(meta_path)
      slug = File.basename(File.dirname(meta_path))

      brand = Linestamp::Brand.find_or_initialize_by(slug: slug)
      brand.assign_attributes(
        character_name: meta["character_name"] || slug.titleize,
        series_name: meta["series_name"] || slug.titleize,
        two_part_definition: meta["two_part_definition"],
        concept: meta["concept"],
        target_audience: meta["target_audience"],
        target_axes: meta["target_axes"] || {},
        tone_axes: meta["tone_axes"] || {},
        purpose_background: meta["purpose_background"],
        character_parts: meta["character_parts"] || {},
        font_spec: meta["font_spec"] || {},
        primary_color: meta["primary_color"] || "#FFFFFF",
        background_color_for_gen: meta["background_color_for_gen"] || "#3CB371",
        description: meta["description"]
      )
      brand.metadata = (brand.metadata || {}).merge(meta.except(
        "character_name", "series_name", "two_part_definition", "concept",
        "target_audience", "target_axes", "tone_axes", "purpose_background",
        "character_parts", "font_spec", "primary_color", "background_color_for_gen", "description"
      ))
      brand.save!

      sync_packs(brand, File.dirname(meta_path))
      brand
    end

    private

    def sync_packs(brand, brand_dir)
      packs_dir = File.join(brand_dir, "packs")
      return unless File.directory?(packs_dir)

      Dir.glob(File.join(packs_dir, "pack_*")).sort.each_with_index do |pack_dir, idx|
        manifest_path = File.join(pack_dir, "manifest.yml")
        next unless File.exist?(manifest_path)

        manifest = YAML.safe_load_file(manifest_path)
        position = idx + 1

        pack = brand.packs.find_or_initialize_by(position: position)
        pack.assign_attributes(
          series_theme: manifest["series_theme"] || "Pack #{position}",
          slug: manifest["slug"],
          layer: manifest["layer"],
          world_view: manifest["world_view"],
          usage_scenes: manifest["usage_scenes"] || [],
          target_emotions: manifest["target_emotions"] || [],
          excluded_elements: manifest["excluded_elements"],
          metadata: (pack.metadata || {}).merge(manifest.except(
            "series_theme", "slug", "layer", "world_view",
            "usage_scenes", "target_emotions", "excluded_elements", "stamps"
          ))
        )
        pack.save!

        sync_stamps(pack, manifest["stamps"]) if manifest["stamps"]
      end
    end

    def sync_stamps(pack, stamps_config)
      return unless stamps_config.is_a?(Array)

      stamps_config.each_with_index do |stamp_cfg, idx|
        position = stamp_cfg["number"] || (idx + 1)
        stamp = pack.stamps.find_or_initialize_by(position: position)
        stamp.assign_attributes(
          label: stamp_cfg["label"],
          situation: stamp_cfg["situation"],
          intent: stamp_cfg["intent"],
          usage_scene: stamp_cfg["usage_scene"],
          pose_spec: stamp_cfg["pose_spec"],
          props: stamp_cfg["props"],
          search_keywords: stamp_cfg["search_keywords"] || [],
          communication_purpose: stamp_cfg["communication_purpose"]
        )
        stamp.save!
      end
    end
  end
end
