class AnalysisReport < ApplicationRecord
  REPORT_TYPES = %w[weekly monthly].freeze
  STATUSES     = %w[draft human_reviewed applied].freeze

  validates :report_type, presence: true, inclusion: { in: REPORT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending_review, -> { where(status: "draft") }
  scope :applied, -> { where(status: "applied") }

  def approvable?
    status == "draft"
  end

  def approve!
    update!(status: "human_reviewed")
  end

  def apply!
    update!(status: "applied")
  end
end
