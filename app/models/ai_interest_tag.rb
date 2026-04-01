class AiInterestTag < ApplicationRecord
  belongs_to :ai_user
  belongs_to :interest_tag

  validates :ai_user_id, uniqueness: { scope: :interest_tag_id }
end
