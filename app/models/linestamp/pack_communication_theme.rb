# frozen_string_literal: true

class Linestamp::PackCommunicationTheme < ApplicationRecord
  self.table_name = "linestamp_pack_communication_themes"

  belongs_to :pack, class_name: "Linestamp::Pack"
  belongs_to :communication_theme, class_name: "Linestamp::CommunicationTheme"

  validates :communication_theme_id, uniqueness: { scope: :pack_id }
  validates :weight, numericality: { in: 0..100 }, allow_nil: true
end
