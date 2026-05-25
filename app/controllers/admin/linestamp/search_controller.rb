# frozen_string_literal: true

module Admin
  module Linestamp
    class SearchController < ApplicationController
      def index
        @axes = ::Linestamp::AttributeAxis.active.ordered.includes(:attribute_values)
        @themes = ::Linestamp::CommunicationTheme.active.ordered

        if search_active?
          result = ::Linestamp::Search::FacetedSearcher.new(search_params).call
          @records = result.records
          @facets = result.facets
          @total_count = result.total_count
        else
          @records = []
          @facets = {}
          @total_count = 0
        end
      end

      private

      def search_active?
        params[:theme].present? || params[:tone].present? || params[:motif].present? ||
          params[:demographic].present? || params[:setting].present?
      end

      def search_params
        params.permit(:target, :limit, :sort, theme: [], tone: [], motif: [], demographic: [], setting: [])
      end
    end
  end
end
