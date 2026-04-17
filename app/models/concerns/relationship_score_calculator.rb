# frozen_string_literal: true

# Shared composite score calculation for relationship jobs.
# NOTE: interest_match, usefulness, proximity, popularity_appeal, obligation,
# and follow_intention are reserved for future AI analysis and currently
# default to 0. Until those dimensions are populated, interaction_score
# alone drives relationship progression via the fallback branch below.
module RelationshipScoreCalculator
  def composite_score(rel)
    other = rel.interest_match + rel.usefulness + rel.proximity +
            rel.popularity_appeal + rel.obligation + rel.follow_intention
    if other.zero?
      rel.interaction_score
    else
      (
        rel.interaction_score * 0.35 +
        rel.interest_match    * 0.15 +
        rel.usefulness        * 0.10 +
        rel.proximity         * 0.10 +
        rel.popularity_appeal * 0.10 +
        rel.obligation        * 0.10 +
        rel.follow_intention  * 0.10
      ).round
    end
  end
end
