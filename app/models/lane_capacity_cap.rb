class LaneCapacityCap < ApplicationRecord
  # Phase 36 / §13: 28日運営レーンの WIP 上限。scope_level + service_id + operating_lane で一意。
  enum :operating_lane, {
    immediate: 0,
    weekly_improvement: 1,
    monthly_ops: 2,
    quarterly_review: 3
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true, scopes: false

  validates :operating_lane, presence: true
  validates :wip_cap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # scope_level + service_id + lane の組で一意
  validates :operating_lane, uniqueness: { scope: [ :scope_level, :service_id ] }
end
