class CostLedger < ApplicationRecord
  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true
  belongs_to :source_ticket, class_name: "TicketLedger", optional: true

  enum :subject_type, {
    meeting: 0,
    ticket: 1,
    artifact: 2,
    job: 3,
    service: 4
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    short_term: 3
  }, prefix: true

  enum :source, {
    llm_api: 0,
    vps_runtime: 1,
    human_hours: 2,
    external_service: 3
  }, prefix: true

  validates :subject_type, :subject_id, :scope_level, :source,
            :amount_jpy, :incurred_at, :recorded_at, presence: true
  validates :amount_jpy, numericality: { greater_than_or_equal_to: 0 }

  before_validation :default_recorded_at

  scope :for_subject, ->(type, id) { where(subject_type: type, subject_id: id) }
  scope :in_period, ->(from, to) { where(incurred_at: from..to) }

  def self.total_amount_jpy(scope = all)
    scope.sum(:amount_jpy)
  end

  private

  def default_recorded_at
    self.recorded_at ||= Time.current
  end
end
