# frozen_string_literal: true

# コミュニケーションテーマ: "何を伝えたいか"の分類マスタ
# 例: 在宅ワーク報告、感謝、謝罪
class Linestamp::CommunicationTheme < ApplicationRecord
  self.table_name = "linestamp_communication_themes"

  belongs_to :parent, class_name: "Linestamp::CommunicationTheme", optional: true
  has_many :children, class_name: "Linestamp::CommunicationTheme", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent

  has_many :brand_communication_themes, class_name: "Linestamp::BrandCommunicationTheme", dependent: :destroy
  has_many :brands, through: :brand_communication_themes

  has_many :pack_communication_themes, class_name: "Linestamp::PackCommunicationTheme", dependent: :destroy
  has_many :packs, through: :pack_communication_themes

  has_many :stamp_communication_themes, class_name: "Linestamp::StampCommunicationTheme", dependent: :destroy
  has_many :stamps, through: :stamp_communication_themes

  has_many :research_communication_themes, class_name: "Linestamp::ResearchCommunicationTheme", dependent: :destroy
  has_many :researches, through: :research_communication_themes

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
end
