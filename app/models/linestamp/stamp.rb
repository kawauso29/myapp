class Linestamp::Stamp < ApplicationRecord
  include AASM

  # Skip guard for syncer operations where themes are set incrementally
  attr_accessor :skip_primary_theme_guard

  belongs_to :pack, class_name: "Linestamp::Pack"
  belongs_to :primary_communication_theme, class_name: "Linestamp::CommunicationTheme", optional: true
  has_one_attached :raw_image
  has_one_attached :processed_image

  has_many :stamp_communication_themes, class_name: "Linestamp::StampCommunicationTheme", dependent: :destroy
  has_many :communication_themes, through: :stamp_communication_themes
  has_many :stamp_attribute_values, class_name: "Linestamp::StampAttributeValue", dependent: :destroy
  has_many :attribute_values, through: :stamp_attribute_values

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :pack_id }
  validate :exactly_one_primary_communication_theme,
           if: -> { !skip_primary_theme_guard && stamp_communication_themes.any? }

  scope :with_themes, ->(theme_ids) {
    joins(:stamp_communication_themes)
      .where(linestamp_stamp_communication_themes: { communication_theme_id: theme_ids }).distinct
  }
  scope :with_attributes, ->(value_ids) {
    joins(:stamp_attribute_values)
      .where(linestamp_stamp_attribute_values: { attribute_value_id: value_ids }).distinct
  }

  # Display label for UI (label is the primary text identifier)
  def display_label
    label.presence || "##{position}"
  end

  def sync_primary_communication_theme_id!
    primary_join = stamp_communication_themes.find_by(primary: true)
    new_id = primary_join&.communication_theme_id
    update_column(:primary_communication_theme_id, new_id) if primary_communication_theme_id != new_id
  end

  aasm column: :status do
    state :planned, initial: true
    state :prompt_ready
    state :raw_uploaded
    state :processing
    state :processed
    state :failed

    event :mark_prompt_ready do
      transitions from: :planned, to: :prompt_ready, guard: :has_prompt?
    end

    event :upload_raw do
      transitions from: %i[planned prompt_ready failed], to: :raw_uploaded
    end

    event :start_processing do
      transitions from: :raw_uploaded, to: :processing
    end

    event :mark_processed do
      transitions from: :processing, to: :processed
    end

    event :upload_processed_directly do
      transitions from: %i[planned prompt_ready raw_uploaded failed], to: :processed
    end

    event :mark_failed do
      transitions from: :processing, to: :failed
    end

    event :reset do
      transitions from: %i[processed failed], to: :raw_uploaded, guard: :has_raw_image?
    end
  end

  private

  def exactly_one_primary_communication_theme
    primaries = stamp_communication_themes.select(&:primary?).count
    errors.add(:base, "primary な communication_theme は1つだけ必要") if primaries != 1
  end

  def has_prompt?
    prompt.present?
  end

  def has_raw_image?
    raw_image.attached?
  end
end
