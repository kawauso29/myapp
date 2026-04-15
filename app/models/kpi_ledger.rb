class KpiLedger < ApplicationRecord
  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    active: 0,
    paused: 1
  }, prefix: true

  validates :kpi_key, :scope_level, :name, :status, presence: true
  validates :kpi_key, uniqueness: true
end
