class TradeResult < ApplicationRecord
  OUTCOMES = %w[win loss skip_correct skip_wrong].freeze

  belongs_to :trade_decision

  validates :outcome, presence: true, inclusion: { in: OUTCOMES }

  scope :wins,  -> { where(outcome: "win") }
  scope :losses, -> { where(outcome: "loss") }

  def win?
    outcome == "win"
  end

  def loss?
    outcome == "loss"
  end
end
