class AiDmMessage < ApplicationRecord
  belongs_to :thread, class_name: "AiDmThread"
  belongs_to :ai_user

  enum :dm_type, {
    greeting: 0, continuation: 1, confession: 2,
    advice: 3, chitchat: 4, comfort: 5
  }, prefix: true

  validates :content, presence: true, length: { maximum: 500 }
end
