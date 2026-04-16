class RolePermission < ApplicationRecord
  # §10 権限境界を DB で機械化するための台帳（補強12）。
  # 「誰（role）が・何を（action）・どの範囲で（scope）できるか」を一意に表現する。
  enum :role, {
    president: 0,
    exec_planning: 1,
    exec_dev: 2,
    exec_audit: 3,
    exec_hr: 4,
    business_lead: 5,
    service_planning: 6,
    dev: 7,
    audit: 8,
    hr: 9,
    customer_success: 10
  }, prefix: true

  enum :action, {
    create_ticket: 0,
    approve_ticket: 1,
    change_kpi: 2,
    halt_service: 3,
    close_service: 4,
    change_company_policy: 5,
    veto: 6,
    release_artifact: 7,
    change_compliance_rule: 8,
    change_role_permission: 9
  }, prefix: true

  enum :scope, {
    company: 0,
    portfolio: 1,
    service: 2,
    short_term: 3
  }, prefix: true

  enum :approver_role, {
    president: 0,
    exec_planning: 1,
    exec_dev: 2,
    exec_audit: 3,
    exec_hr: 4
  }, prefix: true

  validates :role, :action, :scope, presence: true
  validates :role, uniqueness: { scope: [ :action, :scope, :service_id_pattern ] }
  validate :approver_required_when_dual_approval

  scope :allowed_for, ->(role:, action:, scope:) {
    where(role: role, action: action, scope: scope, allowed: true)
  }

  # 指定されたロール・アクション・スコープの組み合わせで許可されているかを判定する。
  # 許可行が存在しない場合は false（= デフォルト拒否）。
  def self.permitted?(role:, action:, scope:, service_id: nil)
    candidates = where(role: role, action: action, scope: scope, allowed: true)
    return false if candidates.empty?

    return true if service_id.blank?

    candidates.any? do |record|
      record.service_id_pattern.blank? ||
        File.fnmatch?(record.service_id_pattern, service_id.to_s)
    end
  end

  private

  def approver_required_when_dual_approval
    return unless requires_dual_approval && approver_role.blank?

    errors.add(:approver_role, "is required when requires_dual_approval is true")
  end
end
