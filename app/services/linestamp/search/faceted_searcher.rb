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
        matching_ids = theme_join_model.where(communication_theme_id: theme_ids).select(fk_column)
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
          matching_ids = join_model.where(attribute_value_id: value_ids).select(fk_column)
          scope = scope.where(id: matching_ids)
        end
        scope
      end

      FK_COLUMNS = { "brand" => :brand_id, "pack" => :pack_id, "stamp" => :stamp_id }.freeze

      def fk_column
        FK_COLUMNS.fetch(@target)
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
            scope.order(published_at: :desc)
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

      ATTRIBUTE_JOIN_TABLES = {
        "brand" => "linestamp_brand_attribute_values",
        "pack" => "linestamp_pack_attribute_values",
        "stamp" => "linestamp_stamp_attribute_values"
      }.freeze

      THEME_JOIN_TABLES = {
        "brand" => "linestamp_brand_communication_themes",
        "pack" => "linestamp_pack_communication_themes",
        "stamp" => "linestamp_stamp_communication_themes"
      }.freeze

      FK_COLUMN_NAMES = { "brand" => "brand_id", "pack" => "pack_id", "stamp" => "stamp_id" }.freeze

      def compute_axis_facet(scope, axis)
        jt = ATTRIBUTE_JOIN_TABLES.fetch(@target)
        fk = FK_COLUMN_NAMES.fetch(@target)

        counts = Linestamp::AttributeValue
          .where(axis: axis, active: true)
          .joins(
            ActiveRecord::Base.sanitize_sql_array(
              ["INNER JOIN #{jt} ON #{jt}.attribute_value_id = linestamp_attribute_values.id"]
            )
          )
          .where("#{jt}.#{fk}" => scope.select(:id))
          .group(:id, :slug, :name)
          .count("#{jt}.id")

        counts.map { |(id, slug, name), count| { id: id, slug: slug, name: name, count: count } }
              .sort_by { |f| -f[:count] }
      end

      def compute_theme_facet(scope)
        jt = THEME_JOIN_TABLES.fetch(@target)
        fk = FK_COLUMN_NAMES.fetch(@target)

        counts = Linestamp::CommunicationTheme
          .where(active: true)
          .joins(
            ActiveRecord::Base.sanitize_sql_array(
              ["INNER JOIN #{jt} ON #{jt}.communication_theme_id = linestamp_communication_themes.id"]
            )
          )
          .where("#{jt}.#{fk}" => scope.select(:id))
          .group(:id, :slug, :name)
          .count("#{jt}.id")

        counts.map { |(id, slug, name), count| { id: id, slug: slug, name: name, count: count } }
              .sort_by { |f| -f[:count] }
      end
    end
  end
end
