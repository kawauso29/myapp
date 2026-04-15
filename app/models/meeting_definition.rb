class MeetingDefinition < ApplicationRecord
  has_many :meeting_ledgers, dependent: :destroy
  has_many :service_heartbeats, dependent: :destroy

  enum :meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  validates :meeting_key, :meeting_type, :scope_level, :chair_role, presence: true
end
