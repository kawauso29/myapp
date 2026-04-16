module Reinforcements
  # Phase 22 / 補強12: role_permissions を参照して「行為許可」を強制する。
  # デフォルト拒否（allowed 行が無ければ PermissionDenied を発火）。
  class PermissionEnforcer
    def self.permitted?(role:, action:, scope:, service_id: nil)
      RolePermission.permitted?(role: role, action: action, scope: scope, service_id: service_id)
    end

    def self.enforce!(role:, action:, scope:, service_id: nil)
      return true if permitted?(role: role, action: action, scope: scope, service_id: service_id)

      raise PermissionDenied.new(
        role: role,
        action: action,
        scope: scope,
        service_id: service_id
      )
    end

    # requires_dual_approval = true の場合、approver_role の明示承認が必要か判定する。
    def self.dual_approval_required?(role:, action:, scope:)
      RolePermission.allowed_for(role: role, action: action, scope: scope)
                    .where(requires_dual_approval: true)
                    .exists?
    end
  end
end
