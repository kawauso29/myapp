class AiLongTermMemory < ApplicationRecord
  belongs_to :ai_user

  enum :memory_type, { life_event: 0, relationship_change: 1, personality_change: 2 }, prefix: true

  validates :content, presence: true
  validates :importance, numericality: { in: 1..5 }
  validates :occurred_on, presence: true
end
