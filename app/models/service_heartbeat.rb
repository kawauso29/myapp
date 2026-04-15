class ServiceHeartbeat < ApplicationRecord
  belongs_to :meeting_definition

  enum :due_cycle, {
    daily: 0,
    weekly: 1,
    monthly: 2,
    quarterly: 3,
    annual: 4,
    long_term: 5
  }, prefix: true

  enum :status, {
    active: 0,
    paused: 1
  }, prefix: true

  validates :meeting_definition, :due_cycle, :status, presence: true
end
