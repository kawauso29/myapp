class HrEvaluationLedger < ApplicationRecord
  # Phase 38 / §19: 人事評価台帳（スケルトン）。
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    draft: 0,
    reviewed: 1,
    finalized: 2
  }, prefix: true

  validates :subject_role, :period_start, :period_end, :scope_level, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validate :period_range_is_valid

  private

  def period_range_is_valid
    return if period_start.blank? || period_end.blank?
    return if period_end >= period_start

    errors.add(:period_end, "must be on or after period_start")
  end
end
