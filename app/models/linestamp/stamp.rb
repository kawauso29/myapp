class Linestamp::Stamp < ApplicationRecord
  include AASM

  belongs_to :pack, class_name: "Linestamp::Pack"
  has_one_attached :raw_image
  has_one_attached :processed_image

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: :pack_id }

  # Display label for UI (label is the primary text identifier)
  def display_label
    label.presence || "##{position}"
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

  def has_prompt?
    prompt.present?
  end

  def has_raw_image?
    raw_image.attached?
  end
end
