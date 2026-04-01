class AiShortTermMemory < ApplicationRecord
  belongs_to :ai_user

  enum :memory_type, { daily_summary: 0, interaction: 1, event: 2 }, prefix: true

  validates :content, presence: true
  validates :importance, numericality: { in: 1..5 }
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
end
