# frozen_string_literal: true

# 属性値: 属性軸に属する具体的な値
# 例: tone軸の "ゆるい"、motif軸の "動物"
class Linestamp::AttributeValue < ApplicationRecord
  self.table_name = "linestamp_attribute_values"

  belongs_to :axis, class_name: "Linestamp::AttributeAxis", inverse_of: :attribute_values

  has_many :brand_attribute_values, class_name: "Linestamp::BrandAttributeValue", dependent: :destroy
  has_many :brands, through: :brand_attribute_values

  has_many :pack_attribute_values, class_name: "Linestamp::PackAttributeValue", dependent: :destroy
  has_many :packs, through: :pack_attribute_values

  has_many :stamp_attribute_values, class_name: "Linestamp::StampAttributeValue", dependent: :destroy
  has_many :stamps, through: :stamp_attribute_values

  has_many :research_attribute_values, class_name: "Linestamp::ResearchAttributeValue", dependent: :destroy
  has_many :researches, through: :research_attribute_values

  validates :slug, presence: true, uniqueness: { scope: :axis_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :for_axis, ->(axis_slug) { joins(:axis).where(linestamp_attribute_axes: { slug: axis_slug }) }
end
