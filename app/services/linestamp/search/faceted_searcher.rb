# frozen_string_literal: true

module Linestamp
  module Search
    class FacetedSearcher
      VALID_TARGETS = %w[brand pack stamp].freeze
      MAX_LIMIT = 100
      DEFAULT_LIMIT = 20

      Result = Struct.new(:records, :facets, :total_count, keyword_init: true)

      def initialize(params)
        @target = params[:target].presence || "pack"
        @theme_slugs = Array(params[:theme]).compact_blank
        @tone_slugs = Array(params[:tone]).compact_blank
        @motif_slugs = Array(params[:motif]).compact_blank
        @demographic_slugs = Array(params[:demographic]).compact_blank
        @setting_slugs = Array(params[:setting]).compact_blank
        @limit = [[params[:limit].to_i, 1].max, MAX_LIMIT].min
        @limit = DEFAULT_LIMIT if params[:limit].blank?
        @sort = params[:sort].presence || default_sort
      end

      def call
        validate_target!
        scope = base_scope
        scope = apply_theme_filter(scope)
        scope = apply_attribute_filters(scope)
        total = scope.count
        records = apply_sort(scope).limit(@limit)
        facets = compute_facets(scope)

        Result.new(records: records, facets: facets, total_count: total)
      end

      private

      def validate_target!
        raise ArgumentError, "target must be one of: #{VALID_TARGETS.join(', ')}" unless VALID_TARGETS.include?(@target)
      end

      def base_scope
        case @target
        when "brand" then Linestamp::Brand.all
        when "pack"  then Linestamp::Pack.all
        when "stamp" then Linestamp::Stamp.all
        end
      end

      def apply_theme_filter(scope)
        return scope if @theme_slugs.empty?

        theme_ids = Linestamp::CommunicationTheme.where(slug: @theme_slugs).pluck(:id)
        return scope.none if theme_ids.empty?

        theme_join_model = theme_join_model_for_target
        fk = :"#{@target}_id"
        matching_ids = theme_join_model.where(communication_theme_id: theme_ids).select(fk)
        scope.where(id: matching_ids)
      end

      def apply_attribute_filters(scope)
        { "tone" => @tone_slugs, "motif" => @motif_slugs,
          "demographic" => @demographic_slugs, "setting" => @setting_slugs }.each do |axis_slug, slugs|
          next if slugs.empty?

          value_ids = Linestamp::AttributeValue
            .joins(:axis)
            .where(linestamp_attribute_axes: { slug: axis_slug }, slug: slugs)
            .pluck(:id)
          next if value_ids.empty?

          # Use subquery to handle multiple axis filters without join conflicts
          join_model = join_model_for_target
          fk = :"#{@target}_id"
          matching_ids = join_model.where(attribute_value_id: value_ids).select(fk)
          scope = scope.where(id: matching_ids)
        end
        scope
      end

      def join_model_for_target
        case @target
        when "brand" then Linestamp::BrandAttributeValue
        when "pack"  then Linestamp::PackAttributeValue
        when "stamp" then Linestamp::StampAttributeValue
        end
      end

      def theme_join_model_for_target
        case @target
        when "brand" then Linestamp::BrandCommunicationTheme
        when "pack"  then Linestamp::PackCommunicationTheme
        when "stamp" then Linestamp::StampCommunicationTheme
        end
      end

      def apply_sort(scope)
        case @sort
        when "sales_count_desc"
          if @target == "pack"
            scope.order(sales_count: :desc)
          else
            scope.order(created_at: :desc)
          end
        when "published_at_desc"
          if @target == "pack"
            scope.order(Arel.sql("linestamp_packs.published_at DESC NULLS LAST"))
          else
            scope.order(created_at: :desc)
          end
        when "created_at_desc"
          scope.order(created_at: :desc)
        else
          scope.order(created_at: :desc)
        end
      end

      def default_sort
        @target == "pack" ? "sales_count_desc" : "created_at_desc"
      end

      def compute_facets(scope)
        facets = {}
        Linestamp::AttributeAxis.active.ordered.each do |axis|
          facets[axis.slug] = compute_axis_facet(scope, axis)
        end
        facets["communication_theme"] = compute_theme_facet(scope)
        facets
      end

      def compute_axis_facet(scope, axis)
        join_table = "linestamp_#{@target}_attribute_values"
        fk_column = "#{@target}_id"

        counts = Linestamp::AttributeValue
          .where(axis: axis, active: true)
          .joins("INNER JOIN #{join_table} ON #{join_table}.attribute_value_id = linestamp_attribute_values.id")
          .where("#{join_table}.#{fk_column}" => scope.select(:id))
          .group(:id, :slug, :name)
          .count("#{join_table}.id")

        counts.map { |(id, slug, name), count| { id: id, slug: slug, name: name, count: count } }
              .sort_by { |f| -f[:count] }
      end

      def compute_theme_facet(scope)
        join_table = "linestamp_#{@target}_communication_themes"
        fk_column = "#{@target}_id"

        counts = Linestamp::CommunicationTheme
          .where(active: true)
          .joins("INNER JOIN #{join_table} ON #{join_table}.communication_theme_id = linestamp_communication_themes.id")
          .where("#{join_table}.#{fk_column}" => scope.select(:id))
          .group(:id, :slug, :name)
          .count("#{join_table}.id")

        counts.map { |(id, slug, name), count| { id: id, slug: slug, name: name, count: count } }
              .sort_by { |f| -f[:count] }
      end
    end
  end
end
