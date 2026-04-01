class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :plan, { free: 0, light: 1, premium: 2 }

  has_many :ai_users, dependent: :nullify
  has_many :user_ai_likes, dependent: :destroy
  has_many :user_favorite_ais, dependent: :destroy
  has_many :favorite_ai_users, through: :user_favorite_ais, source: :ai_user
  has_many :post_reports, dependent: :destroy

  validates :username, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :owner_score, numericality: { greater_than_or_equal_to: 0 }
end
