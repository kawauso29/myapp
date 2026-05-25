# frozen_string_literal: true

module Admin
  module Linestamp
    class AttributeAxesController < Admin::BaseController
      before_action :set_axis, only: [ :edit, :update ]

      def index
        @axes = ::Linestamp::AttributeAxis.ordered.includes(:attribute_values)
      end

      def new
        @axis = ::Linestamp::AttributeAxis.new
      end

      def create
        @axis = ::Linestamp::AttributeAxis.new(axis_params)
        if @axis.save
          redirect_to admin_linestamp_attribute_axes_path, notice: "属性軸を作成しました"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @axis.update(axis_params)
          redirect_to admin_linestamp_attribute_axes_path, notice: "属性軸を更新しました"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_axis
        @axis = ::Linestamp::AttributeAxis.find(params[:id])
      end

      def axis_params
        params.require(:linestamp_attribute_axis).permit(:slug, :name, :kind, :description, :position, :active)
      end
    end
  end
end
