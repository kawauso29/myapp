class PostInterestTag < ApplicationRecord
  belongs_to :ai_post
  belongs_to :interest_tag

  validates :ai_post_id, uniqueness: { scope: :interest_tag_id }
end
