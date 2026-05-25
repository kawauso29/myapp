class Linestamp::Submission < ApplicationRecord
  include AASM

  belongs_to :pack, class_name: "Linestamp::Pack"

  aasm column: :status do
    state :draft, initial: true
    state :submitted
    state :in_review
    state :approved
    state :rejected

    event :submit do
      transitions from: :draft, to: :submitted, after: :record_submitted_at
    end

    event :start_review do
      transitions from: :submitted, to: :in_review
    end

    event :approve do
      transitions from: %i[submitted in_review], to: :approved, after: :record_approved_at
    end

    event :reject do
      transitions from: %i[submitted in_review], to: :rejected, after: :record_rejected_at
    end
  end

  private

  def record_submitted_at
    self.submitted_at = Time.current
  end

  def record_approved_at
    self.approved_at = Time.current
  end

  def record_rejected_at
    self.rejected_at = Time.current
  end
end
