class Linestamp::Research < ApplicationRecord
  include AASM

  validates :title, presence: true

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
