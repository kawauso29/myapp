class Linestamp::Research < ApplicationRecord
  include AASM

  has_many :brands, class_name: "Linestamp::Brand", dependent: :nullify

  has_many :research_communication_themes, class_name: "Linestamp::ResearchCommunicationTheme", dependent: :destroy
  has_many :communication_themes, through: :research_communication_themes
  has_many :research_attribute_values, class_name: "Linestamp::ResearchAttributeValue", dependent: :destroy
  has_many :attribute_values, through: :research_attribute_values

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  aasm column: :status do
    state :draft, initial: true
    state :in_progress
    state :completed
    state :archived

    event :start do
      transitions from: :draft, to: :in_progress
    end

    event :complete do
      transitions from: :in_progress, to: :completed
    end

    event :archive do
      transitions from: %i[draft completed], to: :archived
    end
  end
end
