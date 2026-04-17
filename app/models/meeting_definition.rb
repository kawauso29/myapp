class MeetingDefinition < ApplicationRecord
  has_many :meeting_ledgers, dependent: :destroy
  has_many :service_heartbeats, dependent: :destroy

  enum :meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5,
    quarterly_review: 6,
    annual_plan: 7
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  VALID_CYCLES = %w[daily weekly monthly quarterly annual long_term].freeze

  validates :meeting_key, :meeting_type, :scope_level, :chair_role, presence: true
  validate :allowed_cycles_valid

  # R1: scope_level ごとに許可される周期を allowed_cycles で制御する。
  # 空配列は「全周期許可」と同義（後方互換）。
  def cycle_allowed?(cycle)
    return true if allowed_cycles.blank?

    allowed_cycles.include?(cycle.to_s)
  end

  private

  def allowed_cycles_valid
    return if allowed_cycles.blank?

    invalid = Array(allowed_cycles) - VALID_CYCLES
    return if invalid.empty?

    errors.add(:allowed_cycles, "contains invalid cycles: #{invalid.join(', ')}")
  end
end
