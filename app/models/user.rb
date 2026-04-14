class User < ApplicationRecord
  SUPPORTED_LANGUAGES = %w[ja en ko zh es fr de].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :plan, { free: 0, light: 1, premium: 2 }

  has_many :ai_users, dependent: :nullify
  has_many :user_ai_likes, dependent: :destroy
  has_many :ai_story_reactions, dependent: :destroy
  has_many :user_favorite_ais, dependent: :destroy
  has_many :favorite_ai_users, through: :user_favorite_ais, source: :ai_user
  has_many :post_reports, dependent: :destroy
  has_many :user_notifications, dependent: :destroy, foreign_key: :user_id
  has_many :user_community_follows, dependent: :destroy
  has_many :followed_communities, through: :user_community_follows, source: :ai_community

  validates :username, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :owner_score, numericality: { greater_than_or_equal_to: 0 }
  validates :preferred_language, inclusion: { in: SUPPORTED_LANGUAGES }

  before_validation :set_default_preferred_language

  private

  def set_default_preferred_language
    self.preferred_language = "ja" if preferred_language.blank?
  end
end
