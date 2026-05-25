# frozen_string_literal: true

class Linestamp::BrandCommunicationTheme < ApplicationRecord
  self.table_name = "linestamp_brand_communication_themes"

  belongs_to :brand, class_name: "Linestamp::Brand"
  belongs_to :communication_theme, class_name: "Linestamp::CommunicationTheme"

  validates :communication_theme_id, uniqueness: { scope: :brand_id }
  validates :weight, numericality: { in: 0..100 }, allow_nil: true
end
