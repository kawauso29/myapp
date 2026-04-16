class OperatorOverrideLedger < ApplicationRecord
  enum :action, {
    halt_all: 0,
    halt_scope: 1,
    halt_service: 2,
    resume_all: 10,
    resume_scope: 11,
    resume_service: 12
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2
  }, prefix: true

  validates :action, :scope_level, :operator, :started_at, :reason, presence: true
  validate :service_id_required_for_service_scope
  validate :lifted_after_started

  scope :currently_active, -> {
    where(action: %i[halt_all halt_scope halt_service]).where(lifted_at: nil)
  }

  # 与えられたスコープに対して、現在有効な halt_* が存在するかを判定する。
  # halt_all は常に全体に適用され、halt_scope は scope_level 一致、
  # halt_service は scope_level + service_id 一致で適用される。
  def self.halted?(scope_level: nil, service_id: nil)
    active = currently_active
    return true if active.action_halt_all.exists?

    if scope_level.present?
      scope_query = active.action_halt_scope.where(scope_level: scope_level)
      return true if scope_query.exists?
    end

    if service_id.present?
      service_query = active.action_halt_service
                            .where(scope_level: :service, service_id: service_id)
      return true if service_query.exists?
    end

    false
  end

  private

  def service_id_required_for_service_scope
    return unless scope_level_service? && service_id.blank?

    errors.add(:service_id, "is required when scope_level is service")
  end

  def lifted_after_started
    return if lifted_at.blank? || started_at.blank?
    return if lifted_at >= started_at

    errors.add(:lifted_at, "must be after started_at")
  end
end
