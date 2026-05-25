class Linestamp::ImageSpec < ApplicationRecord
  self.table_name = "linestamp_image_specs"

  has_many :packs, class_name: "Linestamp::Pack", foreign_key: :image_spec_id, inverse_of: :image_spec

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :margin_px, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  def self.default
    find_by(slug: "line_main_370x320")
  end

  def content_width
    width - (margin_px * 2)
  end

  def content_height
    height - (margin_px * 2)
  end
end
