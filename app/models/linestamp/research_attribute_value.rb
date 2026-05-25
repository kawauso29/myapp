# frozen_string_literal: true

class Linestamp::ResearchAttributeValue < ApplicationRecord
  self.table_name = "linestamp_research_attribute_values"

  belongs_to :research, class_name: "Linestamp::Research"
  belongs_to :attribute_value, class_name: "Linestamp::AttributeValue"

  validates :attribute_value_id, uniqueness: { scope: :research_id }
end
