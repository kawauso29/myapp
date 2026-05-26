# frozen_string_literal: true

module Linestamp
  class Importer
    attr_reader :summary

    def self.run(seed_id:, &block)
      importer = new(seed_id)
      importer.instance_eval(&block)
      importer
    end

    def initialize(seed_id)
      @seed_id = seed_id
      @summary = { brands: 0, packs: 0, stamps: 0, researches: 0 }
    end

    # --- Entity upsert ---

    def upsert_brand!(slug:, **attrs)
      brand = Linestamp::Brand.find_or_initialize_by(slug: slug)
      brand.assign_attributes(attrs.merge(imported_from: @seed_id, synced_at: Time.current))
      brand.save!
      @summary[:brands] += 1
      brand
    end

    def upsert_research!(slug:, communication_themes: [], attributes: {}, **attrs)
      research = Linestamp::Research.find_or_initialize_by(slug: slug)
      research.assign_attributes(attrs.merge(imported_from: @seed_id, synced_at: Time.current))
      research.save!
      attach_communication_themes!(research, communication_themes) if communication_themes.any?
      attach_attribute_values!(research, attributes) if attributes.any?
      @summary[:researches] += 1
      research
    end

    def create_pack!(brand:, slug:, stamps: [], communication_themes: [], attributes: {}, **attrs)
      pack = Linestamp::Pack.find_or_initialize_by(brand: brand, slug: slug)
      pack.assign_attributes(attrs.merge(imported_from: @seed_id, synced_at: Time.current))
      pack.save!
      attach_communication_themes!(pack, communication_themes) if communication_themes.any?
      attach_attribute_values!(pack, attributes) if attributes.any?
      stamps.each_with_index do |stamp_cfg, idx|
        create_stamp!(
          pack: pack,
          number: idx + 1,
          **stamp_cfg.merge(imported_from: @seed_id)
        )
      end
      @summary[:packs] += 1
      pack
    end

    def create_stamp!(pack:, number:, label:, primary_communication_theme:,
                      communication_themes: [], attributes: {}, **attrs)
      stamp = Linestamp::Stamp.find_or_initialize_by(pack: pack, position: number)
      stamp.skip_primary_theme_guard = true
      stamp.assign_attributes(
        attrs.except(:imported_from).merge(
          label: label,
          imported_from: @seed_id,
          synced_at: Time.current
        )
      )
      stamp.save!
      all_themes = ([primary_communication_theme] + communication_themes).uniq
      attach_communication_themes!(stamp, all_themes, primary: primary_communication_theme)
      attach_attribute_values!(stamp, attributes) if attributes.any?
      @summary[:stamps] += 1
      stamp
    end

    # --- 中間表ヘルパ ---

    def attach_communication_themes!(record, slugs, primary: nil)
      themes = slugs.map { |s| resolve_communication_theme!(s) }
      join_class = communication_theme_join_class(record)
      fk = foreign_key_for(record)

      join_class.where(fk => record.id).destroy_all
      themes.each do |theme|
        attrs = { fk => record.id, communication_theme_id: theme.id }
        attrs[:primary] = (theme.slug == primary) if join_class.column_names.include?("primary")
        attrs[:weight] = 100 if join_class.column_names.include?("weight")
        join_class.create!(attrs)
      end

      # Sync direct FK for Stamp
      record.sync_primary_communication_theme_id! if record.is_a?(Linestamp::Stamp)
    end

    def attach_attribute_values!(record, axes_hash)
      join_class = attribute_value_join_class(record)
      fk = foreign_key_for(record)

      join_class.where(fk => record.id).destroy_all
      axes_hash.each do |axis_slug, value_slugs|
        Array(value_slugs).each do |value_slug|
          value = resolve_attribute_value!(axis_slug.to_s, value_slug)
          attrs = { fk => record.id, attribute_value_id: value.id }
          attrs[:weight] = 100 if join_class.column_names.include?("weight")
          join_class.create!(attrs)
        end
      end
    end

    private

    def resolve_communication_theme!(slug)
      Linestamp::CommunicationTheme.find_by!(slug: slug)
    rescue ActiveRecord::RecordNotFound
      raise ArgumentError, "Unknown CommunicationTheme slug: '#{slug}'. Available: #{Linestamp::CommunicationTheme.pluck(:slug).join(', ')}"
    end

    def resolve_attribute_value!(axis_slug, value_slug)
      axis = Linestamp::AttributeAxis.find_by!(slug: axis_slug)
      axis.attribute_values.find_by!(slug: value_slug)
    rescue ActiveRecord::RecordNotFound
      raise ArgumentError, "Unknown AttributeValue: axis='#{axis_slug}', value='#{value_slug}'"
    end

    def communication_theme_join_class(record)
      case record
      when Linestamp::Brand    then Linestamp::BrandCommunicationTheme
      when Linestamp::Pack     then Linestamp::PackCommunicationTheme
      when Linestamp::Stamp    then Linestamp::StampCommunicationTheme
      when Linestamp::Research then Linestamp::ResearchCommunicationTheme
      else raise ArgumentError, "Unsupported record type: #{record.class}"
      end
    end

    def attribute_value_join_class(record)
      case record
      when Linestamp::Brand    then Linestamp::BrandAttributeValue
      when Linestamp::Pack     then Linestamp::PackAttributeValue
      when Linestamp::Stamp    then Linestamp::StampAttributeValue
      when Linestamp::Research then Linestamp::ResearchAttributeValue
      else raise ArgumentError, "Unsupported record type: #{record.class}"
      end
    end

    def foreign_key_for(record)
      case record
      when Linestamp::Brand    then :brand_id
      when Linestamp::Pack     then :pack_id
      when Linestamp::Stamp    then :stamp_id
      when Linestamp::Research then :research_id
      end
    end
  end
end
