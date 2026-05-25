# frozen_string_literal: true

class Linestamp::ResearchCommunicationTheme < ApplicationRecord
  self.table_name = "linestamp_research_communication_themes"

  belongs_to :research, class_name: "Linestamp::Research"
  belongs_to :communication_theme, class_name: "Linestamp::CommunicationTheme"

  validates :communication_theme_id, uniqueness: { scope: :research_id }
end
