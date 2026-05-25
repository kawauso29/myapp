class Linestamp::Brand < ApplicationRecord
  include AASM

  has_many :packs, class_name: "Linestamp::Pack", dependent: :destroy
  has_one_attached :base_image

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

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

  private

  def has_brand_prompt?
    brand_prompt.present?
  end

  def has_base_image?
    base_image.attached?
  end
end
