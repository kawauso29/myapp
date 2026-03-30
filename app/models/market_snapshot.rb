class MarketSnapshot < ApplicationRecord
  STATES = %w[trending_bull trending_bear ranging dangerous].freeze

  has_many :agent_judgments, dependent: :destroy
  has_many :trade_decisions, dependent: :destroy

  validates :captured_at, presence: true
  validates :state, presence: true, inclusion: { in: STATES }
  validates :state_confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }, allow_nil: true

  scope :recent, -> { order(captured_at: :desc) }
  scope :dangerous, -> { where(state: "dangerous") }
  scope :tradeable, -> { where.not(state: "dangerous") }

  def dangerous?
    state == "dangerous"
  end

  def confident?
    state_confidence.present? && state_confidence >= 0.7
  end
end
