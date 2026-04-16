FactoryBot.define do
  factory :role_permission do
    role { :exec_audit }
    action { :approve_ticket }
    scope { :company }
    allowed { true }
    requires_dual_approval { false }
  end
end
