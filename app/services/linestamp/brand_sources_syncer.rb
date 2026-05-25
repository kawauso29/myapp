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
        name: meta["name"] || slug.titleize,
        description: meta["description"]
      )
      brand.metadata = (brand.metadata || {}).merge(meta.except("name", "description"))
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
          title: manifest["title"] || "Pack #{position}",
          metadata: (pack.metadata || {}).merge(manifest.except("title", "stamps"))
        )
        pack.save!

        sync_stamps(pack, manifest["stamps"]) if manifest["stamps"]
      end
    end

    def sync_stamps(pack, stamps_config)
      return unless stamps_config.is_a?(Array)

      stamps_config.each_with_index do |stamp_cfg, idx|
        position = idx + 1
        stamp = pack.stamps.find_or_initialize_by(position: position)
        stamp.assign_attributes(
          emotion: stamp_cfg["emotion"],
          text_overlay: stamp_cfg["text"]
        )
        stamp.save!
      end
    end
  end
end
