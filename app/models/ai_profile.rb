class AiProfile < ApplicationRecord
  belongs_to :ai_user

  enum :gender, { male: 0, female: 1, other: 2, unspecified: 3 }, prefix: true
  enum :occupation_type, { employed: 0, freelance: 1, student: 2, unemployed: 3, other_occupation: 4 }, prefix: true
  enum :life_stage, {
    student: 1, single: 2, couple: 3, parent_young: 4,
    parent_school: 5, parent_adult: 6, senior: 7
  }, prefix: true
  enum :family_structure, {
    alone: 1, with_partner: 2, nuclear: 3, single_parent: 4, extended: 5
  }, prefix: true
  enum :relationship_status, {
    single: 0, in_relationship: 1, married: 2, divorced: 3
  }, prefix: true

  validates :name, presence: true, length: { maximum: 50 }
  validates :age, presence: true, numericality: { in: 10..100 }
  validates :bio, length: { maximum: 100 }, allow_nil: true
  validates :num_children, numericality: { greater_than_or_equal_to: 0 }
end
