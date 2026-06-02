class Linestamp::Stamp < ApplicationRecord
  include AASM

  # Skip guard for syncer operations where themes are set incrementally
  attr_accessor :skip_primary_theme_guard

  belongs_to :pack, class_name: "Linestamp::Pack"
  belongs_to :primary_communication_theme, class_name: "Linestamp::CommunicationTheme", optional: true
  has_one_attached :processed_image

  has_many :stamp_communication_themes, class_name: "Linestamp::StampCommunicationTheme", dependent: :destroy
  has_many :communication_themes, through: :stamp_communication_themes
  has_many :stamp_attribute_values, class_name: "Linestamp::StampAttributeValue", dependent: :destroy
  has_many :attribute_values, through: :stamp_attribute_values

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :pack_id }

  # LINE_TAGS_VALIDATION — LINE 検索タグは最大9個
  validate :search_keywords_within_limit
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

  # 透過 + LINE規格化は cowork の line-stamp-packaging スキル側で行うため、
  # Rails は「完成画像(processed_image)を直接受け取る」だけの3状態に簡素化。
  aasm column: :status do
    state :planned, initial: true
    state :prompt_ready
    state :processed

    event :mark_prompt_ready do
      transitions from: :planned, to: :prompt_ready, guard: :has_prompt?
    end

    event :upload_processed_directly do
      transitions from: %i[planned prompt_ready processed], to: :processed
    end

    event :reset do
      transitions from: :processed, to: :prompt_ready, guard: :has_prompt?
      transitions from: :processed, to: :planned
    end
  end

  # レコード作成時に個別スタンプのプロンプトを自動合成する。
  after_commit on: :create do
    if planned? && prompt.blank?
      Linestamp::ComposeStampPromptsJob.perform_later(id)
    end
  end

  private

  def exactly_one_primary_communication_theme
    primaries = stamp_communication_themes.select(&:primary?).count
    errors.add(:base, "primary な communication_theme は1つだけ必要") if primaries != 1
  end

  def search_keywords_within_limit
    return if search_keywords.blank?
    errors.add(:search_keywords, "は最大9個までです") if Array(search_keywords).size > 9
  end

  def has_prompt?
    prompt.present?
  end
end
