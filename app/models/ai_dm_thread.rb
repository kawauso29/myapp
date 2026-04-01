class AiDmThread < ApplicationRecord
  belongs_to :ai_user_a, class_name: "AiUser"
  belongs_to :ai_user_b, class_name: "AiUser"

  has_many :ai_dm_messages, foreign_key: :thread_id, dependent: :destroy

  enum :status, { active: 0, dormant: 1, ended: 2 }, prefix: true

  validates :ai_user_a_id, uniqueness: { scope: :ai_user_b_id }

  def last_sender
    ai_dm_messages.order(created_at: :desc).first&.ai_user
  end

  def participant?(ai_user)
    ai_user_a_id == ai_user.id || ai_user_b_id == ai_user.id
  end
end
