# frozen_string_literal: true

class Linestamp::BrandAttributeValue < ApplicationRecord
  self.table_name = "linestamp_brand_attribute_values"

  belongs_to :brand, class_name: "Linestamp::Brand"
  belongs_to :attribute_value, class_name: "Linestamp::AttributeValue"

  validates :attribute_value_id, uniqueness: { scope: :brand_id }
  validates :weight, numericality: { in: 0..100 }, allow_nil: true
end
