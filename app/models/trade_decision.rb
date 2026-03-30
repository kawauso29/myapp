class TradeDecision < ApplicationRecord
  DECISIONS  = %w[execute skip].freeze
  DIRECTIONS = %w[buy sell].freeze

  belongs_to :market_snapshot
  has_one :trade_result, dependent: :destroy

  validates :decision, presence: true, inclusion: { in: DECISIONS }
  validates :direction, inclusion: { in: DIRECTIONS }, allow_nil: true
  validates :final_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  scope :executed, -> { where(decision: "execute") }
  scope :skipped,  -> { where(decision: "skip") }
end
