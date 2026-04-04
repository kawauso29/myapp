class AiFamilyMember < ApplicationRecord
  belongs_to :ai_user

  enum :relationship, {
    partner: 0,
    child: 1,
    parent: 2,
    sibling: 3
  }

  validates :name, presence: true
  validates :relationship, presence: true

  def age
    return nil unless birth_year
    current_year = Date.current.year
    current_year - birth_year
  end

  def age_label
    return nil unless age
    "#{age}歳"
  end

  # e.g. "リン（3歳・保育園）"
  def description
    parts = [ name ]
    detail = []
    detail << age_label if age
    detail << notes if notes.present?
    parts << "（#{detail.join('・')}）" if detail.any?
    parts.join
  end

  def relationship_label
    case relationship.to_sym
    when :partner then "パートナー"
    when :child   then "子ども"
    when :parent  then "親"
    when :sibling then "きょうだい"
    end
  end
end
