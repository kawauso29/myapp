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

  validates :series_theme, presence: true
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :brand_id }
  validates :slug, uniqueness: { scope: :brand_id }, allow_blank: true

  LAYERS = %w[core_work dream weekend seasonal event].freeze
  validates :layer, inclusion: { in: LAYERS }, allow_blank: true

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
