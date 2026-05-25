# frozen_string_literal: true

class Linestamp::StampAttributeValue < ApplicationRecord
  self.table_name = "linestamp_stamp_attribute_values"

  belongs_to :stamp, class_name: "Linestamp::Stamp"
  belongs_to :attribute_value, class_name: "Linestamp::AttributeValue"

  validates :attribute_value_id, uniqueness: { scope: :stamp_id }
end
