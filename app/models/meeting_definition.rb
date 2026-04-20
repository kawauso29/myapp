class MeetingDefinition < ApplicationRecord
  has_many :meeting_ledgers, dependent: :destroy
  has_many :service_heartbeats, dependent: :destroy

  enum :meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5,
    quarterly_review: 6,
    annual_plan: 7,
    daily: 8
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  VALID_CYCLES = %w[daily weekly monthly quarterly annual long_term].freeze

  validates :meeting_key, :meeting_type, :scope_level, :chair_role, presence: true
  validate :allowed_cycles_valid
  validate :participant_roles_known

  # R1: scope_level ごとに許可される周期を allowed_cycles で制御する。
  # 空配列は「全周期許可」と同義（後方互換）。
  def cycle_allowed?(cycle)
    cycles = normalized_allowed_cycles
    return true if cycles.blank?

    cycles.include?(cycle.to_s)
  end

  private

  def allowed_cycles_valid
    cycles = normalized_allowed_cycles
    return if cycles.blank?

    invalid = cycles - VALID_CYCLES
    return if invalid.empty?

    errors.add(:allowed_cycles, "contains invalid cycles: #{invalid.join(', ')}")
  end

  def normalized_allowed_cycles
    return [] unless self.class.attribute_names.include?("allowed_cycles")

    Array(self[:allowed_cycles]).map(&:to_s)
  end

  # Phase 44d: participant_roles のマスタ検証。
  # OrganizationRole テーブルにデータが存在する場合のみ検証する（後方互換）。
  # テーブル未作成やデータ未投入の環境ではスキップする。
  def participant_roles_known
    return if participant_roles.blank?
    return unless OrganizationRole.table_exists? && OrganizationRole.exists?

    unknown = OrganizationRole.validate_roles(participant_roles)
    return if unknown.empty?

    errors.add(:participant_roles, "contains unknown roles: #{unknown.join(', ')}")
  rescue ActiveRecord::StatementInvalid
    # テーブル未作成の環境（migration 前）ではスキップ
    nil
  end
end
