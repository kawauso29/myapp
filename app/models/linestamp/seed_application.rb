# frozen_string_literal: true

class Linestamp::SeedApplication < ApplicationRecord
  self.table_name = "linestamp_seed_applications"

  STATES = %w[pending applied failed].freeze

  validates :seed_id, presence: true, uniqueness: true
  validates :state, presence: true, inclusion: { in: STATES }

  scope :pending, -> { where(state: "pending") }
  scope :applied, -> { where(state: "applied") }
  scope :failed,  -> { where(state: "failed") }

  def applied?
    state == "applied"
  end

  def pending?
    state == "pending"
  end

  def failed?
    state == "failed"
  end

  def mark_applied!(summary:)
    update!(state: "applied", applied_at: Time.current, result_summary: summary)
  end

  def mark_failed!(error:)
    update!(state: "failed", error_message: error)
  end
end
