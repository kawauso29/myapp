# Pack = ユーザー視点でのシリーズ(LINE申請単位: 8枚)
class Linestamp::Pack < ApplicationRecord
  include AASM

  belongs_to :brand, class_name: "Linestamp::Brand"
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :image_spec, class_name: "Linestamp::ImageSpec", optional: true
  belongs_to :main_source_stamp, class_name: "Linestamp::Stamp", optional: true
  belongs_to :tab_source_stamp, class_name: "Linestamp::Stamp", optional: true
  has_many :stamps, class_name: "Linestamp::Stamp", dependent: :destroy
  has_many :submissions, class_name: "Linestamp::Submission", dependent: :destroy
  has_one_attached :sheet_image
  has_one_attached :main_image
  has_one_attached :tab_image

  has_many :pack_communication_themes, class_name: "Linestamp::PackCommunicationTheme", dependent: :destroy
  has_many :communication_themes, through: :pack_communication_themes
  has_many :pack_attribute_values, class_name: "Linestamp::PackAttributeValue", dependent: :destroy
  has_many :attribute_values, through: :pack_attribute_values

  validates :series_theme, presence: true
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :brand_id }
  validates :slug, uniqueness: { scope: :brand_id }, allow_blank: true

  LAYERS = %w[core_work dream weekend seasonal event].freeze
  validates :layer, inclusion: { in: LAYERS }, allow_blank: true

  ALLOWED_PURCHASE_UNIT_SIZES = [8, 24, 40].freeze
  validates :purchase_unit_size, inclusion: { in: ALLOWED_PURCHASE_UNIT_SIZES }
  validates :sales_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }
  scope :best_sellers, ->(limit = 10) { published.order(sales_count: :desc).limit(limit) }
  scope :with_themes, ->(theme_ids) {
    joins(:pack_communication_themes)
      .where(linestamp_pack_communication_themes: { communication_theme_id: theme_ids }).distinct
  }
  scope :with_attributes, ->(value_ids) {
    joins(:pack_attribute_values)
      .where(linestamp_pack_attribute_values: { attribute_value_id: value_ids }).distinct
  }
  scope :with_axis_value, ->(axis_slug, value_slug) {
    joins(pack_attribute_values: { attribute_value: :axis })
      .where(linestamp_attribute_axes: { slug: axis_slug }, linestamp_attribute_values: { slug: value_slug }).distinct
  }

  aasm column: :status do
    state :planned, initial: true
    state :prompt_ready
    state :in_progress
    state :stamps_complete
    state :approved
    state :submitted

    event :mark_prompt_ready do
      transitions from: :planned, to: :prompt_ready, guard: :has_sheet_prompt?
    end

    event :start_work do
      transitions from: :prompt_ready, to: :in_progress, guard: :brand_base_ready?
    end

    event :mark_stamps_complete do
      transitions from: :in_progress, to: :stamps_complete, guard: :all_stamps_processed?
    end

    event :approve do
      transitions from: :stamps_complete, to: :approved, after: :record_approval
    end

    event :mark_submitted do
      transitions from: :approved, to: :submitted, after: :create_submission_record
    end
  end

  # レコード作成時にシートプロンプトを自動合成する。
  # apply_imports 経由なら同トランザクション内で stamps も作られた後にコミットされ、
  # PromptComposer#compose_pack_prompt が 8 stamps を含むテキストを生成できる。
  after_commit on: :create do
    if planned? && sheet_prompt.blank?
      Linestamp::ComposePackSheetPromptJob.perform_later(id)
    end
  end

  # Display name for UI
  def display_name
    series_theme
  end

  def all_stamps_processed?
    stamps.any? && !stamps.where.not(status: "processed").exists?
  end

  def effective_image_spec
    image_spec || Linestamp::ImageSpec.default
  end

  private

  def has_sheet_prompt?
    sheet_prompt.present?
  end

  def brand_base_ready?
    brand.base_ready?
  end

  def record_approval
    self.approved_at = Time.current
  end

  def create_submission_record
    submissions.create!(status: "draft")
  end
end
