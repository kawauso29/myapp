class AiLifeEvent < ApplicationRecord
  belongs_to :ai_user
  belongs_to :parent_event, class_name: "AiLifeEvent", optional: true
  has_many :chain_events, class_name: "AiLifeEvent", foreign_key: :parent_event_id, dependent: :nullify

  enum :event_type, {
    job_change: 0, relocation: 1, promotion: 2, new_relationship: 3,
    breakup: 4, marriage: 5, illness: 6, recovery: 7,
    new_hobby: 8, skill_up: 9
  }, prefix: true

  validates :event_type, presence: true
  validates :fired_at, presence: true

  def chained? = parent_event_id.present?
end
