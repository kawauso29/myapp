class AiUser < ApplicationRecord
  belongs_to :user, optional: true

  has_one :ai_personality, dependent: :destroy
  has_one :ai_profile, dependent: :destroy
  has_one :ai_avatar_state, dependent: :destroy
  has_one :ai_dynamic_params, dependent: :destroy, class_name: "AiDynamicParams"

  has_many :ai_daily_states, dependent: :destroy
  has_many :ai_life_events, dependent: :destroy
  has_many :ai_posts, dependent: :destroy
  has_many :ai_post_likes, dependent: :destroy
  has_many :ai_short_term_memories, dependent: :destroy
  has_many :ai_long_term_memories, dependent: :destroy

  has_many :ai_interest_tags, dependent: :destroy
  has_many :interest_tags, through: :ai_interest_tags

  has_many :user_favorite_ais, dependent: :destroy
  has_many :favorited_by_users, through: :user_favorite_ais, source: :user

  # Relationships (as source)
  has_many :ai_relationships, dependent: :destroy
  has_many :ai_relationship_memories, dependent: :destroy

  # Relationships (as target)
  has_many :targeted_relationships, class_name: "AiRelationship",
           foreign_key: :target_ai_user_id, dependent: :destroy

  # DM threads
  has_many :dm_threads_as_a, class_name: "AiDmThread",
           foreign_key: :ai_user_a_id, dependent: :destroy
  has_many :dm_threads_as_b, class_name: "AiDmThread",
           foreign_key: :ai_user_b_id, dependent: :destroy

  has_many :ai_dm_messages, dependent: :destroy

  enum :pending_post_theme, {
    job_change: 0, relocation: 1, promotion: 2, new_relationship: 3,
    breakup: 4, marriage: 5, illness: 6, recovery: 7,
    new_hobby: 8, skill_up: 9
  }, prefix: true

  validates :username, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :followers_count, :following_count, :posts_count, :total_likes,
            numericality: { greater_than_or_equal_to: 0 }
  validates :violation_count, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :seed, -> { where(is_seed: true) }

  def dm_threads_as_participant
    AiDmThread.where("ai_user_a_id = :id OR ai_user_b_id = :id", id: id)
  end

  def today_state
    ai_daily_states.find_by(date: Date.current)
  end

  def last_posted_at
    ai_posts.maximum(:created_at)
  end
end
