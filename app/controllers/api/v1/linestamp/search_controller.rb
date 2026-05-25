# frozen_string_literal: true

module Api
  module V1
    module Linestamp
      class SearchController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false

        def index
          result = ::Linestamp::Search::FacetedSearcher.new(search_params).call
          render json: {
            target: search_params[:target] || "pack",
            total_count: result.total_count,
            records: serialize_records(result.records),
            facets: result.facets
          }
        rescue ArgumentError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        private

        def search_params
          params.permit(:target, :limit, :sort, theme: [], tone: [], motif: [], demographic: [], setting: [])
        end

        def serialize_records(records)
          records.map { |r| serialize_record(r) }
        end

        def serialize_record(record)
          base = { id: record.id, type: record.class.name.demodulize.downcase }
          case record
          when ::Linestamp::Brand
            base.merge(slug: record.slug, name: record.series_name, persona_name: record.persona_name,
                       themes: record.communication_themes.pluck(:slug),
                       attributes: record.attribute_values.joins(:axis).pluck("linestamp_attribute_axes.slug", "linestamp_attribute_values.slug"))
          when ::Linestamp::Pack
            base.merge(slug: record.slug, name: record.series_theme, sales_count: record.sales_count,
                       published_at: record.published_at, brand_slug: record.brand.slug,
                       themes: record.communication_themes.pluck(:slug),
                       attributes: record.attribute_values.joins(:axis).pluck("linestamp_attribute_axes.slug", "linestamp_attribute_values.slug"))
          when ::Linestamp::Stamp
            base.merge(label: record.label, position: record.position,
                       primary_theme: record.primary_communication_theme&.slug,
                       pack_slug: record.pack.slug,
                       themes: record.communication_themes.pluck(:slug),
                       attributes: record.attribute_values.joins(:axis).pluck("linestamp_attribute_axes.slug", "linestamp_attribute_values.slug"))
          end
        end
      end
    end
  end
end
