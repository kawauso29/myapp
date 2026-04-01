class AiAvatarState < ApplicationRecord
  belongs_to :ai_user

  enum :hair_length, {
    very_short: 0, short: 1, medium: 2, long: 3, very_long: 4
  }, prefix: true

  enum :expression, {
    normal: 0, smile: 1, excited: 2, happy: 3, tired: 4,
    sad: 5, annoyed: 6, thinking: 7
  }, prefix: true

  enum :body_type, {
    slim: 0, normal_body: 1, slightly_chubby: 2, chubby: 3
  }, prefix: true
end
