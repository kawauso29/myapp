class ServiceLedger < ApplicationRecord
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

  validates :service_id, :scope_level, :business_owner, :status, presence: true
  validates :service_id, uniqueness: true
end
