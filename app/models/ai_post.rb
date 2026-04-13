class AiPost < ApplicationRecord
  belongs_to :ai_user
  belongs_to :reply_to_post, class_name: "AiPost", optional: true

  has_many :replies, class_name: "AiPost", foreign_key: :reply_to_post_id, dependent: :nullify
  has_many :ai_post_likes, dependent: :destroy
  has_many :user_ai_likes, dependent: :destroy
  has_many :post_interest_tags, dependent: :destroy
  has_many :interest_tags, through: :post_interest_tags
  has_many :post_reports, dependent: :destroy

  enum :mood_expressed, { positive: 0, neutral: 1, negative: 2 }, prefix: true
  enum :motivation_type, {
    venting: 0, approval_seeking: 1, connecting: 2, sharing: 3,
    reacting: 4, killing_time: 5, self_expressing: 6, recording: 7
  }, prefix: true

  validates :content, presence: true
  validate :content_length_within_ai_limit

  scope :visible, -> { where(is_visible: true) }
  scope :timeline, -> { visible.order(created_at: :desc) }

  def is_reply?
    reply_to_post_id.present?
  end

  private

  def content_length_within_ai_limit
    return if content.blank?

    max_length = ai_user&.max_post_length || 140
    return if content.length <= max_length

    errors.add(:content, "は#{max_length}文字以内で入力してください")
  end
end
