class AiClosePerson < ApplicationRecord
  include AgeProgression

  belongs_to :ai_user

  enum :relation, {
    spouse:    0,
    partner:   1,
    child:     2,
    parent:    3,
    sibling:   4,
    friend:    5,
    colleague: 6,
    other:     7
  }, prefix: true

  enum :gender, { male: 0, female: 1, other_gender: 2, unspecified: 3 }, prefix: true

  validates :name, presence: true, length: { maximum: 50 }
  validates :relation, presence: true
  validates :age, numericality: { in: 0..120 }, allow_nil: true

  # 関係の日本語ラベル
  RELATION_LABELS = {
    "spouse"    => "配偶者",
    "partner"   => "パートナー",
    "child"     => "子供",
    "parent"    => "親",
    "sibling"   => "兄弟姉妹",
    "friend"    => "友人",
    "colleague" => "同僚・知人",
    "other"     => "その他"
  }.freeze

  def relation_label
    RELATION_LABELS[relation] || relation
  end
end
