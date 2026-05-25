# frozen_string_literal: true

module Admin
  module Linestamp
    class CommunicationThemesController < ApplicationController
      before_action :set_theme, only: [ :edit, :update ]

      def index
        @themes = ::Linestamp::CommunicationTheme.ordered
      end

      def new
        @theme = ::Linestamp::CommunicationTheme.new
      end

      def create
        @theme = ::Linestamp::CommunicationTheme.new(theme_params)
        if @theme.save
          redirect_to admin_linestamp_communication_themes_path, notice: "テーマを作成しました"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @theme.update(theme_params)
          redirect_to admin_linestamp_communication_themes_path, notice: "テーマを更新しました"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_theme
        @theme = ::Linestamp::CommunicationTheme.find(params[:id])
      end

      def theme_params
        params.require(:linestamp_communication_theme).permit(:slug, :name, :description, :position, :active, :parent_id)
      end
    end
  end
end
