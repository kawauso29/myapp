# frozen_string_literal: true

class Linestamp::PackAttributeValue < ApplicationRecord
  self.table_name = "linestamp_pack_attribute_values"

  belongs_to :pack, class_name: "Linestamp::Pack"
  belongs_to :attribute_value, class_name: "Linestamp::AttributeValue"

  validates :attribute_value_id, uniqueness: { scope: :pack_id }
  validates :weight, numericality: { in: 0..100 }, allow_nil: true
end
