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
        description: meta["description"],
        persona_name: meta["persona_name"]
      )
      brand.metadata = (brand.metadata || {}).merge(meta.except(
        "character_name", "series_name", "two_part_definition", "concept",
        "target_audience", "target_axes", "tone_axes", "purpose_background",
        "character_parts", "font_spec", "primary_color", "background_color_for_gen", "description",
        "persona_name", "communication_themes", "attributes"
      ))
      brand.save!

      sync_brand_themes(brand, meta["communication_themes"]) if meta["communication_themes"]
      sync_brand_attributes(brand, meta["attributes"]) if meta["attributes"]
      sync_packs(brand, File.dirname(meta_path))
      brand
    end

    private

    def sync_brand_themes(brand, theme_slugs)
      theme_ids = resolve_theme_ids(theme_slugs)
      brand.brand_communication_themes.where.not(communication_theme_id: theme_ids).destroy_all
      theme_ids.each do |tid|
        brand.brand_communication_themes.find_or_create_by!(communication_theme_id: tid)
      end
    end

    def sync_brand_attributes(brand, attributes_hash)
      value_ids = resolve_attribute_value_ids(attributes_hash)
      brand.brand_attribute_values.where.not(attribute_value_id: value_ids).destroy_all
      value_ids.each do |vid|
        brand.brand_attribute_values.find_or_create_by!(attribute_value_id: vid)
      end
    end

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
          purchase_unit_size: manifest["purchase_unit_size"] || 8,
          metadata: (pack.metadata || {}).merge(manifest.except(
            "series_theme", "slug", "layer", "world_view",
            "usage_scenes", "target_emotions", "excluded_elements", "stamps",
            "communication_themes", "attributes", "purchase_unit_size"
          ))
        )
        # Never touch published_at or sales_count from yml
        pack.save!

        sync_pack_themes(pack, manifest["communication_themes"]) if manifest["communication_themes"]
        sync_pack_attributes(pack, manifest["attributes"]) if manifest["attributes"]
        sync_stamps(pack, manifest["stamps"]) if manifest["stamps"]
      end
    end

    def sync_pack_themes(pack, theme_slugs)
      theme_ids = resolve_theme_ids(theme_slugs)
      pack.pack_communication_themes.where.not(communication_theme_id: theme_ids).destroy_all
      theme_ids.each do |tid|
        pack.pack_communication_themes.find_or_create_by!(communication_theme_id: tid)
      end
    end

    def sync_pack_attributes(pack, attributes_hash)
      value_ids = resolve_attribute_value_ids(attributes_hash)
      pack.pack_attribute_values.where.not(attribute_value_id: value_ids).destroy_all
      value_ids.each do |vid|
        pack.pack_attribute_values.find_or_create_by!(attribute_value_id: vid)
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

        sync_stamp_themes(stamp, stamp_cfg) if stamp_cfg["primary_communication_theme"] || stamp_cfg["communication_themes"]
      end
    end

    def sync_stamp_themes(stamp, stamp_cfg)
      primary_slug = stamp_cfg["primary_communication_theme"]
      all_slugs = Array(stamp_cfg["communication_themes"])
      all_slugs << primary_slug if primary_slug && !all_slugs.include?(primary_slug)

      theme_ids = resolve_theme_ids(all_slugs)
      stamp.stamp_communication_themes.where.not(communication_theme_id: theme_ids).destroy_all

      theme_ids.each do |tid|
        join = stamp.stamp_communication_themes.find_or_create_by!(communication_theme_id: tid)
        is_primary = primary_slug && (Linestamp::CommunicationTheme.find(tid).slug == primary_slug)
        join.update!(primary: is_primary) if join.primary? != is_primary
      end

      stamp.sync_primary_communication_theme_id!
    end

    def resolve_theme_ids(slugs)
      return [] if slugs.blank?

      ids = []
      Array(slugs).each do |slug|
        theme = Linestamp::CommunicationTheme.find_by(slug: slug)
        if theme
          ids << theme.id
        else
          Rails.logger.warn("[BrandSourcesSyncer] Unknown communication_theme slug: #{slug} — skipped")
        end
      end
      ids
    end

    def resolve_attribute_value_ids(attributes_hash)
      return [] if attributes_hash.blank?

      ids = []
      attributes_hash.each do |axis_slug, value_slugs|
        axis = Linestamp::AttributeAxis.find_by(slug: axis_slug)
        unless axis
          Rails.logger.warn("[BrandSourcesSyncer] Unknown attribute_axis slug: #{axis_slug} — skipped")
          next
        end
        Array(value_slugs).each do |vs|
          val = Linestamp::AttributeValue.find_by(axis: axis, slug: vs)
          if val
            ids << val.id
          else
            Rails.logger.warn("[BrandSourcesSyncer] Unknown attribute_value slug: #{vs} for axis #{axis_slug} — skipped")
          end
        end
      end
      ids
    end
  end
end
