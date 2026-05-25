# frozen_string_literal: true

module Admin
  module Linestamp
    class AttributeValuesController < ApplicationController
      before_action :set_value, only: [ :edit, :update ]

      def index
        @values = ::Linestamp::AttributeValue.ordered.includes(:axis)
        @values = @values.for_axis(params[:axis]) if params[:axis].present?
      end

      def new
        @value = ::Linestamp::AttributeValue.new
        @axes = ::Linestamp::AttributeAxis.ordered
      end

      def create
        @value = ::Linestamp::AttributeValue.new(value_params)
        if @value.save
          redirect_to admin_linestamp_attribute_values_path, notice: "属性値を作成しました"
        else
          @axes = ::Linestamp::AttributeAxis.ordered
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @axes = ::Linestamp::AttributeAxis.ordered
      end

      def update
        if @value.update(value_params)
          redirect_to admin_linestamp_attribute_values_path, notice: "属性値を更新しました"
        else
          @axes = ::Linestamp::AttributeAxis.ordered
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_value
        @value = ::Linestamp::AttributeValue.find(params[:id])
      end

      def value_params
        params.require(:linestamp_attribute_value).permit(:axis_id, :slug, :name, :description, :position, :active)
      end
    end
  end
end
