# frozen_string_literal: true

# 属性軸: tone / motif / demographic / setting の4種固定
class Linestamp::AttributeAxis < ApplicationRecord
  self.table_name = "linestamp_attribute_axes"

  has_many :attribute_values, class_name: "Linestamp::AttributeValue", foreign_key: :axis_id, dependent: :destroy, inverse_of: :axis

  KINDS = %w[tone motif demographic setting].freeze

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
end
