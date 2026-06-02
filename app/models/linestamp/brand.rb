class Linestamp::Brand < ApplicationRecord
  include AASM

  belongs_to :research, class_name: "Linestamp::Research", optional: true

  has_many :packs, class_name: "Linestamp::Pack", dependent: :destroy
  has_one_attached :base_image

  has_many :brand_communication_themes, class_name: "Linestamp::BrandCommunicationTheme", dependent: :destroy
  has_many :communication_themes, through: :brand_communication_themes
  has_many :brand_attribute_values, class_name: "Linestamp::BrandAttributeValue", dependent: :destroy
  has_many :attribute_values, through: :brand_attribute_values

  validates :slug, presence: true, uniqueness: true
  validates :character_name, presence: true
  validates :series_name, presence: true

  # LINE_META_VALIDATIONS — コピーライト表記上限
  validates :line_copyright, length: { maximum: 50 }, allow_blank: true

  CHROMA_GREEN = "#3CB371"

  before_validation :enforce_chroma_green
  validates :background_color_for_gen,
            format: { with: /\A#3CB371\z/i, message: "は #3CB371(透過用シーグリーン)固定です" }

  scope :with_themes, ->(theme_ids) {
    joins(:brand_communication_themes)
      .where(linestamp_brand_communication_themes: { communication_theme_id: theme_ids }).distinct
  }
  scope :with_attributes, ->(value_ids) {
    joins(:brand_attribute_values)
      .where(linestamp_brand_attribute_values: { attribute_value_id: value_ids }).distinct
  }
  scope :with_axis_value, ->(axis_slug, value_slug) {
    joins(brand_attribute_values: { attribute_value: :axis })
      .where(linestamp_attribute_axes: { slug: axis_slug }, linestamp_attribute_values: { slug: value_slug }).distinct
  }

  aasm column: :status do
    state :planned, initial: true
    state :prompt_ready
    state :base_ready

    event :mark_prompt_ready do
      transitions from: :planned, to: :prompt_ready, guard: :has_brand_prompt?
    end

    event :mark_base_ready do
      transitions from: :prompt_ready, to: :base_ready, guard: :has_base_image?
    end
  end

  # レコード作成時にプロンプトを自動合成する。
  # apply_imports は ActiveRecord::Base.transaction で eval を囲んでいるため、
  # CT / 属性 attach が同じトランザクション内で完了した状態で発火する。
  after_commit on: :create do
    if planned? && brand_prompt.blank?
      Linestamp::ComposeBrandPromptJob.perform_later(id)
    end
  end

  # Display name for UI (character name is the primary identifier)
  def display_name
    character_name
  end

  # Returns attribute values for a specific axis (e.g. "tone", "motif")
  def attribute_values_by_axis(axis_slug)
    attribute_values.joins(:axis).where(linestamp_attribute_axes: { slug: axis_slug })
  end

  private

  def has_brand_prompt?
    brand_prompt.present?
  end

  def has_base_image?
    base_image.attached?
  end

  def enforce_chroma_green
    self.background_color_for_gen = CHROMA_GREEN if background_color_for_gen.blank?
  end
end
