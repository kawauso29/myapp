class PortfolioStrategyLedger < ApplicationRecord
  # Phase 41 / §4.2: ポートフォリオ戦略台帳（スケルトン）。
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true

  enum :strategy_type, {
    kpi_allocation: 0,
    investment: 1,
    exit: 2,
    merger: 3,
    rebalance: 4
  }, prefix: true

  enum :status, {
    draft: 0,
    active: 1,
    paused: 2,
    completed: 3,
    abandoned: 4
  }, prefix: true

  validates :strategy_key, presence: true, uniqueness: true
  validates :title, :strategy_type, :period_start, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validate :period_end_is_after_start

  private

  def period_end_is_after_start
    return if period_end.blank? || period_start.blank?
    return if period_end >= period_start

    errors.add(:period_end, "must be on or after period_start")
  end
end
