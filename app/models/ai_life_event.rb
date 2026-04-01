class AiLifeEvent < ApplicationRecord
  belongs_to :ai_user

  enum :event_type, {
    job_change: 0, relocation: 1, promotion: 2, new_relationship: 3,
    breakup: 4, marriage: 5, illness: 6, recovery: 7,
    new_hobby: 8, skill_up: 9
  }, prefix: true

  validates :event_type, presence: true
  validates :fired_at, presence: true
end
