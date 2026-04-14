class AiStoryReaction < ApplicationRecord
  ALLOWED_EMOJIS = %w[🔥 ❤️ 😂 😮 😢 👏].freeze

  belongs_to :ai_post
  belongs_to :user

  validates :emoji, presence: true, inclusion: { in: ALLOWED_EMOJIS }
  validates :user_id, uniqueness: { scope: :ai_post_id }
  validate :story_post_only

  private

  def story_post_only
    return if ai_post&.story?

    errors.add(:ai_post, "はストーリー投稿のみリアクションできます")
  end
end
