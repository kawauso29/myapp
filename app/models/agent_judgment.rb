class AgentJudgment < ApplicationRecord
  AGENT_TYPES = %w[macro technical momentum event_risk sentiment].freeze
  JUDGMENTS   = %w[buy sell skip].freeze

  belongs_to :market_snapshot

  validates :agent_type, presence: true, inclusion: { in: AGENT_TYPES }
  validates :judgment, presence: true, inclusion: { in: JUDGMENTS }
  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }, allow_nil: true

  scope :vetoed, -> { where(veto: true) }
  scope :for_agent, ->(type) { where(agent_type: type) }
end
